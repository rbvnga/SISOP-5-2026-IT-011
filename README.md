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
#### output
<img width="804" height="126" alt="1_output kernel" src="https://github.com/user-attachments/assets/645d82cc-8f1c-4bc5-84b7-0eaf8ba8bd03" /> <br>

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
#### output
<img width="887" height="104" alt="1_output single" src="https://github.com/user-attachments/assets/d0e748a5-d7e9-4089-b0f1-b42dc601ceb0" /> <br>

### multi.sh
Script ini membuat filesystem dengan 5 user, lengkap dengan password, akses kontrol, dan banner login. Output disimpan sebagai `osboot/multi.gz`.

#### Spesifikasi User

| User | Password |
|---|---|
| root | (enter) |
| henn | henn123 |
| hann | hann123 |
| viii | viii123 |
| kids | kids123 |

#### Spesifikasi Akses
| User | Access |
|---|---|
| root | Akses penuh ke semua direktori |
| henn | Full akses `/home/*`, gabisa akses `/root` |
| hann | Full akses `/home/{hann,viii,kids}`, gabisa `/root` & `/home/henn` |
| viii | Full akses `/home/{viii,kids}`, gabisa `/root` & `/home/{henn,hann}` |
| kids | Full akses `/home/kids`, gabisa `/root` & `/home/{henn,hann,viii}` |
| ALL | Selain specs diatas cuma bisa read dan execute, full akses `tmp/` |

```bash
#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

# Compile switchuser
if [ ! -f /tmp/switchuser ]; then
    cat > /tmp/switchuser.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pwd.h>
#include <grp.h>

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;
    struct passwd *pw = getpwnam(argv[1]);
    if (!pw) { fprintf(stderr, "user not found\n"); return 1; }
    if (initgroups(pw->pw_name, pw->pw_gid) != 0) { perror("initgroups"); return 1; }
    if (setgid(pw->pw_gid) != 0) { perror("setgid"); return 1; }
    if (setuid(pw->pw_uid) != 0) { perror("setuid"); return 1; }
    setenv("USER",    pw->pw_name, 1);
    setenv("LOGNAME", pw->pw_name, 1);
    setenv("HOME",    pw->pw_dir,  1);
    setenv("PATH",    "/bin",      1);
    chdir(pw->pw_dir);
    char *sh[] = {"/bin/sh", NULL};
    execv("/bin/sh", sh);
    return 1;
}
EOF
    gcc -static -o /tmp/switchuser /tmp/switchuser.c
fi

mkdir -p osboot
rm -rf multi_fs
mkdir -p multi_fs/{bin,dev,proc,sys,etc,tmp,root}
mkdir -p multi_fs/home/{henn,hann,viii,kids}
cd multi_fs

# Scaffold BusyBox
cp /usr/bin/busybox bin/busybox
bin/busybox --install -s bin/
ln -sf /bin/busybox bin/sh
cp /tmp/switchuser bin/switchuser
chmod +x bin/switchuser

# Hash password
ROOT_HASH=$(openssl passwd -6 "root123")
HENN_HASH=$(openssl passwd -6 "henn123")
HANN_HASH=$(openssl passwd -6 "hann123")
VIII_HASH=$(openssl passwd -6 "viii123")
KIDS_HASH=$(openssl passwd -6 "kids123")

cat > etc/passwd << EOF
root:x:0:0:root:/root:/bin/sh
henn:x:1001:1001:henn:/home/henn:/bin/sh
hann:x:1002:1002:hann:/home/hann:/bin/sh
viii:x:1003:1003:viii:/home/viii:/bin/sh
kids:x:1004:1004:kids:/home/kids:/bin/sh
EOF

cat > etc/shadow << EOF
root:${ROOT_HASH}:19000:0:99999:7:::
henn:${HENN_HASH}:19000:0:99999:7:::
hann:${HANN_HASH}:19000:0:99999:7:::
viii:${VIII_HASH}:19000:0:99999:7:::
kids:${KIDS_HASH}:19000:0:99999:7:::
EOF
chmod 640 etc/shadow


# /home/hann (GID 1002) 
# /home/viii (GID 1003)
# /home/kids (GID 1004) 
cat > etc/group << EOF
root:x:0:root
henn:x:1001:henn
hann:x:1002:hann,henn
viii:x:1003:viii,henn,hann
kids:x:1004:kids,henn,hann,viii
EOF

cat > init << 'INITEOF'
#!/bin/busybox sh

/bin/busybox mount -t proc none /proc
/bin/busybox mount -t sysfs none /sys
/bin/busybox mount -t devtmpfs none /dev 2>/dev/null
/bin/busybox mount -t tmpfs none /tmp
/bin/busybox chmod 1777 /tmp

# /root: hanya root
/bin/busybox chown 0:0       /root      && /bin/busybox chmod 700 /root

# /home/henn: hanya henn, semua lain gabisa
/bin/busybox chown 1001:1001 /home/henn && /bin/busybox chmod 700 /home/henn

# /home/hann: owner hann, group hann (hanya henn yg ada di group) → viii,kids gabisa
/bin/busybox chown 1002:1002 /home/hann && /bin/busybox chmod 750 /home/hann

# /home/viii: owner viii, group viii (henn,hann ada di group) → kids gabisa
/bin/busybox chown 1003:1003 /home/viii && /bin/busybox chmod 750 /home/viii

# /home/kids: owner kids, group kids (henn,hann,viii ada di group) → semua bisa
/bin/busybox chown 1004:1004 /home/kids && /bin/busybox chmod 750 /home/kids

while true; do
    /bin/busybox printf "\nlogin: "
    read USERNAME
    [ -z "$USERNAME" ] && continue

    /bin/busybox printf "Password: "
    stty -echo 2>/dev/null
    read PASSWORD
    stty echo 2>/dev/null
    /bin/busybox echo ""

    case "$USERNAME" in
        root) EXPECTED="root123" ;;
        henn) EXPECTED="henn123" ;;
        hann) EXPECTED="hann123" ;;
        viii) EXPECTED="viii123" ;;
        kids) EXPECTED="kids123" ;;
        *)    EXPECTED=""        ;;
    esac

    if [ -z "$EXPECTED" ] || [ "$PASSWORD" != "$EXPECTED" ]; then
        /bin/busybox echo "Login incorrect"
        continue
    fi

    /bin/busybox echo "  _____                        _ _   ____            _          "
    /bin/busybox echo " |  ___|_ _ _ __ _____      _____| | | |  _ \ __ _ _ __| |_ _   _  "
    /bin/busybox echo " | |_ / _\` | '__/ _ \ \ /\ / / _ \ | | | |_) / _\` | '__| __| | | | "
    /bin/busybox echo " |  _| (_| | | |  __/\ V  V /  __/ | | |  __/ (_| | |  | |_| |_| | "
    /bin/busybox echo " |_|  \__,_|_|  \___| \_/\_/ \___|_|_| |_|   \__,_|_|   \__|\__, | "
    /bin/busybox echo "                                                                |___/ "
    /bin/busybox echo ""
    /bin/busybox echo "Welcome, $USERNAME"
    /bin/busybox echo ""

    /bin/switchuser "$USERNAME"

done
INITEOF
chmod +x init

find . | cpio -o --format=newc | gzip > "$BASE_DIR/osboot/multi.gz"
cd "$BASE_DIR"
rm -rf multi_fs
echo "[+] Done! Output: osboot/multi.gz"
```
#### output
<img width="987" height="104" alt="1_output multi" src="https://github.com/user-attachments/assets/f16f2cc3-2ea4-417b-81b0-3ff6be98975b" />

<br>

### iso.sh
Menggabungkan `bzImage`, `single.gz`, dan `multi.gz` menjadi satu file ISO bootable menggunakan GRUB. Output disimpan sebagai `osboot/farewell.iso`. <br>
```bash
#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO_DIR="$BASE_DIR/iso_root"

rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot/grub"

# Copy artifacts
cp "$BASE_DIR/osboot/bzImage"    "$ISO_DIR/boot/"
cp "$BASE_DIR/osboot/single.gz"  "$ISO_DIR/boot/"
cp "$BASE_DIR/osboot/multi.gz"   "$ISO_DIR/boot/"

# GRUB config — bisa pilih single atau multi
cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
set timeout=5
set default=0

menuentry "Farewell Party - Single User" {
    linux  /boot/bzImage console=ttyS0 rdinit=/init quiet
    initrd /boot/single.gz
}

menuentry "Farewell Party - Multi User" {
    linux  /boot/bzImage console=ttyS0 rdinit=/init quiet
    initrd /boot/multi.gz
}
EOF

# Buat ISO
grub-mkrescue -o "$BASE_DIR/osboot/farewell.iso" "$ISO_DIR"
rm -rf "$ISO_DIR"
echo "[+] Done! Output: osboot/farewell.iso"
```
### qemu.sh
Script ini menjalankan OS yang sudah dibuat menggunakan emulator QEMU. <br>

```bash
#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL="$BASE_DIR/osboot/bzImage"
SINGLE="$BASE_DIR/osboot/single.gz"
MULTI="$BASE_DIR/osboot/multi.gz"
ISO="$BASE_DIR/osboot/farewell.iso"

QEMU_NET="-netdev user,id=net0 -device virtio-net-pci,netdev=net0"
QEMU_BASE="-m 512M -nographic $QEMU_NET"

case "$1" in
    --single)
        qemu-system-x86_64 $QEMU_BASE \
            -kernel "$KERNEL" \
            -initrd "$SINGLE" \
            -append "console=ttyS0 rdinit=/init quiet"
        ;;
    --multi)
        qemu-system-x86_64 $QEMU_BASE \
            -kernel "$KERNEL" \
            -initrd "$MULTI" \
            -append "console=ttyS0 rdinit=/init quiet"
        ;;
    --all)
        qemu-system-x86_64 $QEMU_BASE \
            -cdrom "$ISO" \
            -boot d
        ;;
    *)
        echo "Usage: $0 --single | --multi | --all"
        exit 1
        ;;
esac
```
#### output
```bash
./qemu.sh --single   # Boot single-user filesystem
```
<img width="1014" height="620" alt="1_Single" src="https://github.com/user-attachments/assets/8083e06c-4ebd-40f5-8480-0544eaddcecf" />

```bash
./qemu.sh --multi    # Boot multi-user filesystem
```
<img width="1049" height="850" alt="1_user root" src="https://github.com/user-attachments/assets/0bcbc8c1-38fc-4b6a-9938-b0e75b867f5f" /> <br>
<img width="1058" height="887" alt="1_user henn" src="https://github.com/user-attachments/assets/9b6b1879-ba56-4395-815a-de1508a10db2" /> <br>
<img width="1020" height="887" alt="1_user hann" src="https://github.com/user-attachments/assets/3fbcb4e8-dcfe-4f5f-b589-398e63d32d97" /> <br>
<img width="1007" height="913" alt="1_user viii" src="https://github.com/user-attachments/assets/95f82567-4704-4e27-a671-daa3db6d050b" /> <br>
<img width="1033" height="942" alt="1_user kids" src="https://github.com/user-attachments/assets/bf7b5709-61cd-489d-9a7d-6de3da612bb8" /> <br>

```bash
./qemu.sh --all      # Boot dari ISO (pilih single/multi)
```
<img width="1187" height="774" alt="1_all" src="https://github.com/user-attachments/assets/987958be-4ed1-4bb9-955b-649b7ba45de7" /> <br>
<img width="1133" height="657" alt="1_all(single)" src="https://github.com/user-attachments/assets/243dfa8b-cd9d-433a-a0e0-51e47d4af375" /> <br>
<img width="1020" height="733" alt="1_all(multi)" src="https://github.com/user-attachments/assets/b53d33a6-40bf-4419-b58f-2c4333b0c260" /> <br>



### backup.sh 
script ini mengarsip semua hasil build ke dalam satu file ZIP dengan format nama `farewell_backup_[DDMMYYYY-HHMMSS].zip`. <br>
```c
#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +"%d%m%Y-%H%M%S")
BACKUP_NAME="farewell_backup_[${TIMESTAMP}].zip"

cd "$BASE_DIR/osboot"
zip "$BASE_DIR/$BACKUP_NAME" bzImage single.gz multi.gz farewell.iso

# Hapus file yang sudah diarsip dari osboot/
rm -f bzImage single.gz multi.gz farewell.iso

echo "[+] Done! Backup: $BACKUP_NAME"
```
#### output
<img width="830" height="217" alt="1_backup" src="https://github.com/user-attachments/assets/354fb56d-2bf9-49ef-a9f1-2fec31813eb0" /> <br>

### Tes Koneksi ke Akses Internet
<img width="1200" height="988" alt="1_Akses Internet" src="https://github.com/user-attachments/assets/bd15a9d2-efc9-4ea2-9d3f-3b9438df22d9" />
<br>

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

### Hasil
<img width="834" height="567" alt="2_make run" src="https://github.com/user-attachments/assets/1aa6860b-e83e-4baf-a36c-0a4d2c646b5e" />

