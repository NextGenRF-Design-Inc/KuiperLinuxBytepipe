#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/finalize-sd.sh [BOOT_PATH]'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# -le 1 ]] || fail 'Expected optional BOOT_PATH.'
boot_required "${1:-}"
for artifact in Image BOOT.BIN system.dtb; do file_required "$BOOT_PATH/$artifact"; done
# boot.txt assumes mmc 0:1 for BOOT and /dev/mmcblk0p2 for root.
copy_file "$MY_APP_DIR/prebuilt/boot.scr" "$BOOT_PATH/boot.scr"
sync
printf 'Boot files installed. Safely unmount/eject %s before removing the card.\n' "$BOOT_PATH"
