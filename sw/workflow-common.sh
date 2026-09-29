#!/usr/bin/env bash
# Shared helpers for README workflows. Source this file, do not execute it.
set -euo pipefail
SW_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
MY_APP_DIR=$(cd -- "$SW_DIR/.." && pwd -P)
WORKSPACE="$MY_APP_DIR/workspace"
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || fail "Required command not found: $1"; }
file_required() { [[ -f $1 ]] || fail "File not found: $1"; }
model_required() {
    case ${1:-} in 3CG|3EG) MODEL=$1 ;; *) fail 'Model must be 3CG or 3EG.' ;; esac
}
boot_required() {
    BOOT_PATH=${1:-${BOOT_PATH:-}}
    [[ $BOOT_PATH == /* && -d $BOOT_PATH && -w $BOOT_PATH ]] ||
        fail 'Provide an existing, writable, absolute BOOT partition mount path.'
    BOOT_PATH=$(cd -- "$BOOT_PATH" && pwd -P)
    need mountpoint
    mountpoint -q -- "$BOOT_PATH" || fail "Not a mounted partition: $BOOT_PATH"
    [[ $BOOT_PATH != / ]] || fail 'The BOOT partition must not be /.'
}
copy_file() {
    file_required "$1"
    cp -f -- "$1" "$2"
    printf 'Copied %s -> %s\n' "$1" "$2"
}
workspace() { mkdir -p -- "$WORKSPACE"; }
compiler() {
    export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
    need "${CROSS_COMPILE}gcc"
}
xilinx_tools() {
    : "${XILINX_ROOT:?Set XILINX_ROOT to the directory containing Vivado/ and Vitis/.}"
    file_required "$XILINX_ROOT/Vivado/2023.2/settings64.sh"
    file_required "$XILINX_ROOT/Vitis/2023.2/settings64.sh"
    # Vendor setup scripts may read unset environment variables.
    set +u
    source "$XILINX_ROOT/Vivado/2023.2/settings64.sh"
    source "$XILINX_ROOT/Vitis/2023.2/settings64.sh"
    set -u
}
clone_source() {
    local url=$1 branch=$2 target=$3
    # Do not reset or clean a user's existing source checkout automatically.
    [[ ! -e $target ]] || fail "Source directory already exists: $target. Preserve or move it before starting a fresh build."
    git clone --depth 1 --branch "$branch" "$url" "$target"
}
