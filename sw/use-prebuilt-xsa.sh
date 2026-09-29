#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/use-prebuilt-xsa.sh 3CG|3EG'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# == 1 ]] || fail 'Expected model.'
model_required "$1"
workspace
copy_file "$MY_APP_DIR/prebuilt/$MODEL/system_top.xsa" "$WORKSPACE/system_top.xsa"
