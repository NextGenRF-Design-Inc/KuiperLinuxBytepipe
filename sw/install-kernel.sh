#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/install-kernel.sh prebuilt|stock [BOOT_PATH]'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# -ge 1 && $# -le 2 ]] || fail 'Expected prebuilt|stock and optional BOOT_PATH.'
case $1 in prebuilt|stock) ;; *) fail 'Choose prebuilt or stock.' ;; esac
boot_required "${2:-}"
case $1 in
    prebuilt) copy_file "$MY_APP_DIR/prebuilt/Image" "$BOOT_PATH/Image" ;;
    stock) copy_file "$BOOT_PATH/zynqmp-common/Image" "$BOOT_PATH/Image" ;;
esac
