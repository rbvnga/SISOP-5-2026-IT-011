# SISOP-5-2026-IT-011
Nama : Revalinda Bunga Nayla Laksono <br>
NRP : 5027251011 <br>

## Soal 1 - Farewell Party 
### kernel.sh
Script ini bertugas untuk mengunduh source code Linux kernel versi **6.1.1**, mengkonfigurasi, mengompilasi, dan menyimpan hasilnya sebagai `osboot/bzImage`.
```bash
#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

mkdir -p osboot

# Download kernel jika belum ada
if [ ! -f linux-6.1.1.tar.xz ]; then
    echo "[*] Downloading Linux 6.1.1..."
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.1.tar.xz
fi

# Extract jika belum ada
if [ ! -d linux-6.1.1 ]; then
    echo "[*] Extracting..."
    tar -xf linux-6.1.1.tar.xz
fi

cd "$BASE_DIR/linux-6.1.1"

echo "[*] Configuring kernel..."
make defconfig

# Disable EFI (tidak diperlukan di QEMU tanpa UEFI)
scripts/config --disable CONFIG_EFI_STUB
scripts/config --disable CONFIG_EFI

# Compile
echo "[*] Compiling kernel (pakai $(nproc) core)..."
make -j$(nproc) \
    KCFLAGS="-std=gnu11 -Wno-error" \
    HOSTCFLAGS="-std=gnu11 -Wno-error" \
    CC="gcc -std=gnu11" \
    HOSTCC="gcc -std=gnu11"

# Copy hasil
cp arch/x86/boot/bzImage "$BASE_DIR/osboot/bzImage"
echo "[+] Done! Output: osboot/bzImage"
```
#### Flag Kompilasi
```bash
make -j$(nproc) \
    KCFLAGS="-std=gnu11 -Wno-error" \
    HOSTCFLAGS="-std=gnu11 -Wno-error" \
    CC="gcc -std=gnu11" \
    HOSTCC="gcc -std=gnu11"
```

| Flag | Penjelasan |
|---|---|
| `-j$(nproc)` | Kompilasi paralel sesuai jumlah core CPU |
| `-std=gnu11` | Gunakan standar C11 (fix error C23 pada GCC terbaru) |
| `-Wno-error` | Warning tidak dijadikan error (fix beberapa warning di kernel 6.1.1) |
| `CC` dan `HOSTCC` | Override compiler untuk kernel dan host tools |

**Catatan:** Flag ini diperlukan karena GCC versi terbaru (15.x) menggunakan C23 sebagai default, sedangkan Linux kernel 6.1.1 belum kompatibel dengan C23.

### single.sh
Script ini membuat filesystem minimal dengan satu user (root) menggunakan BusyBox sebagai shell environment. Output disimpan sebagai `osboot/single.gz`. <br>
### Spesifikasi
| Item | Value |
|---|---|
| User | root |
| Directory | `bin/, dev/, proc/, sys/, etc/, tmp/, root/` |
| Access | root bisa akses apapun |
| Output | `osboot/single.gz` |
```bash
#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

mkdir -p osboot
rm -rf single_fs
mkdir -p single_fs/{bin,dev,proc,sys,etc,tmp,root}
cd single_fs

# Scaffold BusyBox
cp /usr/bin/busybox bin/busybox
bin/busybox --install -s bin/

# Init script
cat > init << 'EOF'
#!/bin/busybox sh
/bin/busybox mount -t proc none /proc
/bin/busybox mount -t sysfs none /sys
/bin/busybox mount -t devtmpfs none /dev 2>/dev/null
/bin/busybox mount -t tmpfs none /tmp
/bin/busybox chmod 1777 /tmp

echo "  _____                        _ _   ____            _          "
echo " |  ___|_ _ _ __ _____      _____| | | |  _ \ __ _ _ __| |_ _   _  "
echo " | |_ / _\` | '__/ _ \ \ /\ / / _ \ | | | |_) / _\` | '__| __| | | | "
echo " |  _| (_| | | |  __/\ V  V /  __/ | | |  __/ (_| | |  | |_| |_| | "
echo " |_|  \__,_|_|  \___| \_/\_/ \___|_|_| |_|   \__,_|_|   \__|\__, | "
echo "                                                                |___/ "
echo ""
echo "Welcome, root"
echo ""
exec /bin/busybox sh
EOF
chmod +x init

find . | cpio -o --format=newc | gzip > "$BASE_DIR/osboot/single.gz"
cd "$BASE_DIR"
rm -rf single_fs
echo "[+] Done! Output: osboot/single.gz"
```

## Soal 2 - Season
Mengimplementasikan mini OS shell sederhana yang berjalan di emulator Bochs x86-64. Shell ini mendukung berbagai command seperti operasi matematika, tampilan warna, dan lainnya. <br>
### bochsrc.txt
Pastikan terlehih dahulu apakah file `BIOS-bochs-latest` dan `VGABIOS-lgpl-latest` sudah tersedia, dengan command <br>
``````bash
ls /usr/share/bochs/
``````
```txt
romimage: file=/usr/share/bochs/BIOS-bochs-latest
vgaromimage: file=/usr/share/bochs/VGABIOS-lgpl-latest
boot: floppy
floppya: 1_44=floppy.img, status=inserted
log: bochslog.txt
mouse: enabled=0
display_library: sdl2
```
`romimage` berisi file BIOS (program pertama yang dijalankan saat komputer nyala, sebelum bootloader) yang dibituhkan Bochs. Sedangkan `vgaromimage` berisi file VGA BIOS, yang mengatur bagaimana tampilan/layar bekerja di emulator. <br>
`mouse: enabled=0` untuk menonaktifkan mouse, karena OS hanya membutuhkan Keyboard. <br>
`display_library: sdl2` adalah library yang dipakai Bochs untuk menampilkan layar emulator di linux. <br>
### kernel.asm 
```asm
bits 16

global _start
global _putInMemory
global _getChar
extern _main

_start:

    cli

    mov ax, cs
    mov ds, ax
    mov es, ax

    sti

    call _main

.hang:
    jmp .hang


_putInMemory:
    push bp
    mov bp, sp

    push ds

    mov ax, [bp+4]
    mov si, [bp+6]
    mov cl, [bp+8]

    mov ds, ax
    mov [si], cl

    pop ds

    pop bp
    ret

; implement this
_getChar:
    mov ah, 0x00
    int 0x16
    xor ah, ah
    ret
```
- Fungsi `_getChar` adalah fungsi Assembly yang bertugas membaca input keyboard dari pengguna. Fungsi ini perlu dibuat di Assembly karena tidak ada library apapun (no stdlib), sehingga satu-satunya cara untuk berkomunikasi langsung dengan hardware keyboard adalah melalui BIOS interrupt. <br>
Baris pertama akan mengisi register `AH` dengan nilai `0x00`. Register `AH` berfungsi seperti "kode perintah" yang memberitahu BIOS apa yang di minta dan nilai `0x00` akan meminta untuk membaca tombil keyboard yang ditekan pengguna. <br>
- `int 0x16` adalah perintah untuk memanggil BIOS interrupt nomor 16, yaitu interrupt yang khusus menangani keyboard. Ketika baris ini dijalankan, program akan berhenti sejenak dan menunggu sampai pengguna benar-benar menekan sebuah tombol. Setelah tombol ditekan, BIOS menyimpan hasilnya di dua register sekaligus, yaitu `AL` yang berisi karakter ASCII dari tombol tersebut, dan `AH` yang berisi scan code atau kode fisik tombol yang tidak di butuhkan. <br>
- `xor ah, ah` akan mengosongkan register `AH` yang tidak dibutuhkan. Cara kerjanya adalah dengan melakukan operasi XOR antara AH dengan dirinya sendiri, karena XOR suatu nilai dengan dirinya sendiri selalu menghasilkan nol. <br>
- `ret` mengembalikan eksekusi program ke pemanggilnya yaitu fungsi `getChar()` di `kernel.c`, sekaligus membawa nilai karakter yang tadi ditekan sebagai return value. Inilah yang kemudian digunakan oleh `readString()` untuk menyusun string input dari pengguna karakter demi karakter. <br> 
### kernel.c
```c
int cursor;
char color;

void putInMemory(int segment, int address, char character);
int getChar();

void printChar(char c) {
    putInMemory(0xB800, cursor * 2, c);
    putInMemory(0xB800, cursor * 2 + 1, color);
    cursor++;
}

void newline() {
    int col;
    col = cursor - (cursor / 80) * 80;
    cursor = cursor + (80 - col);
}

void printString(char *str) {
    int i;
    i = 0;
    while (str[i] != '\0') {
        printChar(str[i]);
        i++;
    }
}

void clearScreen() {
    int i;
    for (i = 0; i < 2000; i++) {
        putInMemory(0xB800, i * 2, ' ');
        putInMemory(0xB800, i * 2 + 1, 0x07);
    }
    cursor = 0;
    color = 0x07;
}

void readString(char *buf) {
    int i;
    char c;
    i = 0;
    while (1) {
        c = getChar();
        if (c == '\r') {
            break;
        } else if (c == '\b' && i > 0) {
            i--;
            cursor--;
            printChar(' ');
            cursor--;
        } else if (c >= 32) {
            buf[i] = c;
            i++;
            printChar(c);
        }
    }
    buf[i] = '\0';
}

int strcmp(char *a, char *b) {
    int i;
    i = 0;
    while (a[i] != '\0' && b[i] != '\0') {
        if (a[i] != b[i]) return 0;
        i++;
    }
    return a[i] == '\0' && b[i] == '\0';
}

int startsWith(char *str, char *prefix) {
    int i;
    i = 0;
    while (prefix[i] != '\0') {
        if (str[i] != prefix[i]) return 0;
        i++;
    }
    return 1;
}

int atoi(char *str) {
    int result;
    int i;
    result = 0;
    i = 0;
    while (str[i] >= '0' && str[i] <= '9') {
        result = result * 10 + (str[i] - '0');
        i++;
    }
    return result;
}

void intToString(int n, char *buf) {
    int i;
    int j;
    int temp;
    char rev[20];
    i = 0;
    if (n == 0) {
        buf[0] = '0';
        buf[1] = '\0';
        return;
    }
    temp = n;
    while (temp > 0) {
        rev[i] = '0' + (temp - (temp / 10) * 10);
        temp = temp / 10;
        i++;
    }
    for (j = 0; j < i; j++) {
        buf[j] = rev[i - j - 1];
    }
    buf[i] = '\0';
}

int factorial(int n) {
    int result;
    int i;
    result = 1;
    for (i = 2; i <= n; i++) {
        result = result * i;
    }
    return result;
}

void main() {
    char cmd[64];
    char buf[20];
    char *p;
    char *name;
    int a;
    int b;
    int n;
    int i;
    int j;

    cursor = 0;
    color = 0x07;

    clearScreen();

    printString("Welcome to Assistant's Last Gift");
    newline();
    printString("type 'help'");
    newline();
    newline();

    while (1) {
        printString("> ");
        readString(cmd);
        newline();

        if (strcmp(cmd, "check")) {
            printString("ok");

        } else if (strcmp(cmd, "help")) {
            printString("check add sub fac season triangle clear about");

        } else if (strcmp(cmd, "clear")) {
            clearScreen();

        } else if (startsWith(cmd, "add ")) {
            p = cmd + 4;
            a = atoi(p);
            while (*p != ' ') p++;
            p++;
            b = atoi(p);
            intToString(a + b, buf);
            printString(buf);

        } else if (startsWith(cmd, "sub ")) {
            p = cmd + 4;
            a = atoi(p);
            while (*p != ' ') p++;
            p++;
            b = atoi(p);
            intToString(a - b, buf);
            printString(buf);

        } else if (startsWith(cmd, "fac ")) {
            n = atoi(cmd + 4);
            if (n > 8) {
                printString("know your limit little bro.");
            } else {
                intToString(factorial(n), buf);
                printString(buf);
            }

        } else if (startsWith(cmd, "season ")) {
            name = cmd + 7;
            if (strcmp(name, "winter")) {
                color = 0x09;
                printString("winter mode");
            } else if (strcmp(name, "spring")) {
                color = 0x0A;
                printString("spring mode");
            } else if (strcmp(name, "summer")) {
                color = 0x0E;
                printString("summer mode");
            } else if (strcmp(name, "fall")) {
                color = 0x0C;
                printString("fall mode");
            } else if (strcmp(name, "radiant")) {
                color = 0x0D;
                printString("radiant mode");
            }

        } else if (startsWith(cmd, "triangle ")) {
            n = atoi(cmd + 9);
            for (i = 1; i <= n; i++) {
                for (j = 0; j < i; j++) {
                    printChar('x');
                }
                newline();
            }
        }

        newline();
    }
}
```
variabel global `cursor`  menyimpan posisi saat ini di layar, sedangkan `color` menyimpan warna teks yang sedang aktif, dengan nilai awal `0x07` yang berarti teks putih dengan latar belakang hitam. Selain itu, terdapat dua deklarasi fungsi eksternal yaitu putInMemory dan getChar. Kedua fungsi ini tidak didefinisikan di kernel.c melainkan di kernel.asm, sehingga perlu dideklarasikan terlebih dahulu agar compiler tahu bahwa fungsi tersebut ada. <br>

- Fungsi `printChar` bertugas mencetak satu karakter ke layar dengan cara menulis langsung ke VGA memory.
- Fungsi `newline` bertugas memindahkan kursor ke awal baris berikutnya.
- Fungsi `printString` bertugas mencetak sebuah string karakter demi karakter. Fungsi ini bekerja dengan cara melakukan perulangan dari indeks pertama string hingga menemukan karakter null \0 yang menandakan akhir string.
- Fungsi `clearScreen` bertugas membersihkan seluruh layar.
- Fungsi `readString` bertugas membaca input dari keyboard karakter demi karakter dan menyimpannya ke dalam sebuah buffer. Fungsi ini terus membaca karakter menggunakan `getChar` dalam sebuah perulangan tanpa henti.
- Fungsi `strcmp` bertugas membandingkan dua string apakah isinya sama persis atau tidak.
- Fungsi `startsWith` bertugas mengecek apakah sebuah string diawali dengan kata tertentu
- Fungsi `atoi` bertugas mengubah string angka menjadi nilai integer.
- Fungsi `intToString` bertugas mengubah nilai integer menjadi string agar bisa ditampilkan di layar menggunakan `printString`.
- Fungsi `factorial` bertugas menghitung nilai faktorial dari sebuah angka.
  
