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
