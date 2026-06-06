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

# Install libfuse3-dev jika belum ada
if ! dpkg -l libfuse3-dev &>/dev/null; then
    echo "[*] Installing libfuse3-dev..."
    sudo apt-get install -y libfuse3-dev pkg-config
fi

# Compile hello_fuse
cat > /tmp/hello_fuse.c << 'EOF'
#define FUSE_USE_VERSION 31
#include <fuse.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>

static int hello_getattr(const char *path, struct stat *st,
                          struct fuse_file_info *fi) {
    memset(st, 0, sizeof(struct stat));
    if (strcmp(path, "/") == 0) {
        st->st_mode = S_IFDIR | 0755;
        st->st_nlink = 2;
    } else if (strcmp(path, "/hello.txt") == 0) {
        st->st_mode = S_IFREG | 0644;
        st->st_nlink = 1;
        st->st_size = 13;
    } else return -ENOENT;
    return 0;
}

static int hello_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                          off_t offset, struct fuse_file_info *fi,
                          enum fuse_readdir_flags flags) {
    if (strcmp(path, "/") != 0) return -ENOENT;
    filler(buf, ".",         NULL, 0, 0);
    filler(buf, "..",        NULL, 0, 0);
    filler(buf, "hello.txt", NULL, 0, 0);
    return 0;
}

static int hello_read(const char *path, char *buf, size_t size,
                       off_t offset, struct fuse_file_info *fi) {
    if (strcmp(path, "/hello.txt") != 0) return -ENOENT;
    const char *content = "Hello, FUSE!\n";
    size_t len = strlen(content);
    if (offset >= (off_t)len) return 0;
    if (offset + size > len) size = len - offset;
    memcpy(buf, content + offset, size);
    return size;
}

static struct fuse_operations ops = {
    .getattr = hello_getattr,
    .readdir = hello_readdir,
    .read    = hello_read,
};

int main(int argc, char *argv[]) {
    return fuse_main(argc, argv, &ops, NULL);
}
EOF

gcc /tmp/hello_fuse.c -o /tmp/hello_fuse $(pkg-config --cflags --libs fuse3)
echo "[*] hello_fuse compiled"

# Path library di Kali Linux
LIBFUSE="/usr/lib/x86_64-linux-gnu/libfuse3.so.4"
LIBC="/usr/lib/x86_64-linux-gnu/libc.so.6"
LDLINUX="/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"

mkdir -p osboot
rm -rf multi_fs
mkdir -p multi_fs/{bin,dev,proc,sys,etc,tmp,root,mnt}
mkdir -p multi_fs/home/{henn,hann,viii,kids}
mkdir -p multi_fs/lib64
mkdir -p multi_fs/usr/lib
cd multi_fs

# Scaffold BusyBox
cp /usr/bin/busybox bin/busybox
bin/busybox --install -s bin/
ln -sf /bin/busybox bin/sh
cp /tmp/switchuser bin/switchuser
chmod +x bin/switchuser

# Copy hello_fuse
cp /tmp/hello_fuse bin/hello_fuse
chmod +x bin/hello_fuse

# Copy dynamic linker dan libraries
cp "$LDLINUX" lib64/ld-linux-x86-64.so.2
cp "$LIBFUSE"  usr/lib/libfuse3.so.4
ln -sf libfuse3.so.4 usr/lib/libfuse3.so.3
cp "$LIBC"     usr/lib/libc.so.6

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

cat > etc/group << EOF
root:x:0:root
henn:x:1001:henn
hann:x:1002:hann,henn
viii:x:1003:viii,henn,hann
kids:x:1004:kids,henn,hann,viii
EOF

# Package manager 'party'
cat > bin/party << 'EOF'
#!/bin/busybox sh

TMPDIR="/tmp/party_tmp"
MIRROR="https://dl-cdn.alpinelinux.org/alpine/v3.18/main/x86_64"

usage() {
    echo "Usage: party install <package>"
    echo "       party update"
    exit 1
}

case "$1" in
    install)
        [ -z "$2" ] && usage
        PKG="$2"
        echo "[party] Installing: $PKG"
        mkdir -p "$TMPDIR"

        wget -q --no-check-certificate \
            "$MIRROR/APKINDEX.tar.gz" \
            -O "$TMPDIR/APKINDEX.tar.gz" 2>/dev/null

        VER=$(tar -xzf "$TMPDIR/APKINDEX.tar.gz" -O 2>/dev/null | \
            awk -v pkg="$PKG" '
                /^P:/ { p = ($0 == "P:" pkg) }
                /^V:/ && p { print substr($0, 3); exit }
            ')

        if [ -n "$VER" ]; then
            FILENAME="${PKG}-${VER}.apk"
        else
            FILENAME="${PKG}.apk"
        fi

        echo "[party] Downloading: $FILENAME"
        wget -q --no-check-certificate \
            "$MIRROR/$FILENAME" \
            -O "$TMPDIR/pkg.apk" 2>/dev/null

        if [ -f "$TMPDIR/pkg.apk" ] && [ -s "$TMPDIR/pkg.apk" ]; then
            tar -xzf "$TMPDIR/pkg.apk" -C / 2>/dev/null || true
            echo "[party] $PKG installed successfully"
        else
            echo "[party] Failed to install $PKG"
        fi
        rm -rf "$TMPDIR"
        ;;
    update)
        echo "[party] Updating package index..."
        mkdir -p "$TMPDIR"
        wget -q --no-check-certificate \
            "$MIRROR/APKINDEX.tar.gz" \
            -O "$TMPDIR/APKINDEX.tar.gz" 2>/dev/null && \
            echo "[party] Done" || echo "[party] Failed"
        rm -rf "$TMPDIR"
        ;;
    *)
        usage
        ;;
esac
EOF
chmod +x bin/party

cat > init << 'INITEOF'
#!/bin/busybox sh

/bin/busybox mount -t proc none /proc
/bin/busybox mount -t sysfs none /sys
/bin/busybox mount -t devtmpfs none /dev 2>/dev/null
/bin/busybox mount -t tmpfs none /tmp
/bin/busybox chmod 1777 /tmp

# Network otomatis
/bin/busybox ifconfig eth0 10.0.2.15 netmask 255.255.255.0 2>/dev/null
/bin/busybox route add -net 10.0.2.0 netmask 255.255.255.0 dev eth0 2>/dev/null
/bin/busybox route add default gw 10.0.2.2 dev eth0 2>/dev/null
/bin/busybox echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Set LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib

# Permissions
/bin/busybox chown 0:0       /root      && /bin/busybox chmod 700 /root
/bin/busybox chown 1001:1001 /home/henn && /bin/busybox chmod 700 /home/henn
/bin/busybox chown 1002:1002 /home/hann && /bin/busybox chmod 750 /home/hann
/bin/busybox chown 1003:1003 /home/viii && /bin/busybox chmod 750 /home/viii
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
