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
