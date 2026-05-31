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
