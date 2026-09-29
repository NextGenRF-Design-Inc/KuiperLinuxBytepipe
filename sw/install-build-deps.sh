#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: bash sw/install-build-deps.sh'
    exit 0
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/workflow-common.sh"
[[ $# == 0 ]] || fail 'No arguments expected.'
need sudo
sudo apt update
sudo apt install -y git build-essential gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    bc bison flex libssl-dev libelf-dev device-tree-compiler u-boot-tools \
    libgnutls28-dev libncurses-dev python3 python3-dev python3-setuptools \
    python3-pyelftools swig unzip
