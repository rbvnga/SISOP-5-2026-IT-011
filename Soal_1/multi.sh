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

# Mapping group sesuai soal:
# /home/hann (GID 1002) → henn bisa, viii & kids gabisa
# /home/viii (GID 1003) → henn & hann bisa, kids gabisa
# /home/kids (GID 1004) → henn, hann & viii bisa
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
