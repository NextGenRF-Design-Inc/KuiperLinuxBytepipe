#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/compile-uboot.sh'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# == 0 ]] || fail 'No arguments expected.'
need git
need make
compiler
workspace
export ARCH=arm
clone_source https://github.com/Xilinx/u-boot-xlnx.git xilinx-v2023.2 "$MY_APP_DIR/u-boot-xlnx"
cd "$MY_APP_DIR/u-boot-xlnx"
make xilinx_zynqmp_virt_defconfig
copy_file "$SW_DIR/bytepipe_uboot.dts" arch/arm/dts/bytepipe_uboot.dts
bash "$SW_DIR/register-uboot-dts.sh" bytepipe_uboot.dtb
make -j"$(nproc)" DEVICE_TREE=bytepipe_uboot
copy_file u-boot.elf "$WORKSPACE/u-boot.elf"
