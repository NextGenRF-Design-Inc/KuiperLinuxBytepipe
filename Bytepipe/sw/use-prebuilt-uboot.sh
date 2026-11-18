#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/use-prebuilt-uboot.sh'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# == 0 ]] || fail 'No arguments expected.'
workspace
copy_file "$MY_APP_DIR/prebuilt/u-boot.elf" "$WORKSPACE/u-boot.elf"
