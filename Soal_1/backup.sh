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

