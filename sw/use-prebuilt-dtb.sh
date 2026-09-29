#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/use-prebuilt-dtb.sh [BOOT_PATH]'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# -le 1 ]] || fail 'Expected optional BOOT_PATH.'
boot_required "${1:-}"
copy_file "$MY_APP_DIR/prebuilt/system.dtb" "$BOOT_PATH/system.dtb"
