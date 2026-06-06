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
scripts/config --enable CONFIG_FUSE_FS

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
