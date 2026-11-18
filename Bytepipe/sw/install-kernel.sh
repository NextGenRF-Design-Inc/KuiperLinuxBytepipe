#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    cat <<'HELP'
Usage:
  bash sw/install-kernel.sh prebuilt|stock --device /dev/sdX [--cache-dir DIRECTORY]
    Download, verify, flash the whole SD card, mount BOOT, and install the kernel.
    Linux only. Requires interactive erase confirmation and sudo for disk access.
  bash sw/install-kernel.sh prebuilt|stock [BOOT_PATH]
    Copy the kernel to an already flashed and mounted BOOT partition.
HELP
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# -ge 1 ]] || fail 'Expected prebuilt|stock. See --help.'
case $1 in prebuilt|stock) ;; *) fail 'Choose prebuilt or stock.' ;; esac
if [[ ${2:-} == --device ]]; then
    need python3
    kernel=$1
    shift
    exec python3 "$SW_DIR/flash-kuiper.py" --kernel "$kernel" "$@"
fi
[[ $# -le 2 ]] || fail 'Expected BOOT_PATH or --device DEVICE [--cache-dir DIRECTORY].'
boot_required "${2:-}"
case $1 in
    prebuilt) copy_file "$MY_APP_DIR/prebuilt/Image" "$BOOT_PATH/Image" ;;
    stock) copy_file "$BOOT_PATH/zynqmp-common/Image" "$BOOT_PATH/Image" ;;
esac
