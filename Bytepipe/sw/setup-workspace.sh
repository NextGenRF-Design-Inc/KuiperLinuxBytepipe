#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/setup-workspace.sh'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# == 0 ]] || fail 'No arguments expected.'
workspace
printf 'Repository: %s\nWorkspace: %s\n' "$MY_APP_DIR" "$WORKSPACE"
