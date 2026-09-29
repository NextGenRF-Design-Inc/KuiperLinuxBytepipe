#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/compile-dtb.sh [BOOT_PATH]'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# -le 1 ]] || fail 'Expected optional BOOT_PATH.'
# Validate the destination before downloading or building anything.
boot_required "${1:-}"
need git
need make
compiler
workspace
export ARCH=arm64
clone_source https://github.com/analogdevicesinc/linux.git 2023_r2_p1 "$MY_APP_DIR/linux-adi-2023-r2-p1"
cd "$MY_APP_DIR/linux-adi-2023-r2-p1"
make adi_zynqmp_defconfig
copy_file "$SW_DIR/bytepipe.dts" arch/arm64/boot/dts/xilinx/bytepipe.dts
bash "$SW_DIR/add-zynqmp-dtb.sh" bytepipe.dtb
make xilinx/bytepipe.dtb
copy_file arch/arm64/boot/dts/xilinx/bytepipe.dtb "$WORKSPACE/system.dtb"
copy_file "$WORKSPACE/system.dtb" "$BOOT_PATH/system.dtb"
