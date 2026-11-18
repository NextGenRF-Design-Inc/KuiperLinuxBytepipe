#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: XILINX_ROOT=/opt/Xilinx bash sw/compile-boot-bin.sh 3CG|3EG [BOOT_PATH]'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# -ge 1 && $# -le 2 ]] || fail 'Expected model and optional BOOT_PATH.'
model_required "$1"
boot_required "${2:-}"
xilinx_tools
for tool in xsct bootgen vitis git make aarch64-linux-gnu-gcc; do need "$tool"; done
file_required "$WORKSPACE/system_top.xsa"
file_required "$WORKSPACE/u-boot.elf"
copy_file "$MY_APP_DIR/prebuilt/zynqmp_fsbl_${MODEL,,}.elf" "$WORKSPACE/fsbl.elf"
cd "$WORKSPACE"
bash "$SW_DIR/build_zynqmp_boot_bin_external_fsbl.sh" system_top.xsa u-boot.elf download
copy_file "$WORKSPACE/output_boot_bin/BOOT.BIN" "$BOOT_PATH/BOOT.BIN"
