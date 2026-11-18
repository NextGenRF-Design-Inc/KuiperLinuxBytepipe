#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: XILINX_ROOT=/opt/Xilinx bash sw/compile-xsa.sh 3CG|3EG'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# == 1 ]] || fail 'Expected model.'
model_required "$1"
# The existing HDL Makefile does not support whitespace in project paths.
[[ $MY_APP_DIR != *[[:space:]]* ]] || fail 'The HDL build requires a repository path without whitespace.'
xilinx_tools
need vivado
need make
need git
workspace
cd "$WORKSPACE"
# Linux Makefile uses DEV (full part) and lowercase mode.
make -f ../hdl/Makefile DEV="xczu${MODEL,,}-sbva484-1-e" mode=lvds XSA_NAME=system_top.xsa
file_required "$WORKSPACE/system_top.xsa"
