#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/use-prebuilt-boot-bin.sh 3CG|3EG [BOOT_PATH]'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# -ge 1 && $# -le 2 ]] || fail 'Expected model and optional BOOT_PATH.'
model_required "$1"
boot_required "${2:-}"
copy_file "$MY_APP_DIR/prebuilt/BOOT_$MODEL.BIN" "$BOOT_PATH/BOOT.BIN"
