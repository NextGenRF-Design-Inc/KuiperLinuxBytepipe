# KuiperLinux
Tutorial for running Kuiper Linux on the Bytepipe

### What is this?
This README is a guide that illustrates how to set up a Kuiper Linux SD card that works with the Bytepipe.
  - **Quick Start:** follow the tutorial and use prebuilt files as directed.
  - **Build components from source:** Build the HDL, U-Boot, device tree, and BOOT.BIN using the sections below. The supplied kernel and model-specific FSBL remain prebuilt; this guide does not rebuild them.

### Why Kuiper Linux?
Kuiper Linux is pre-loaded with thousands of drivers for ADI products. This provides greater ease when developing with the ADRV9002 installed on the Bytepipe.

In addition, GNU Radio is pre-installed to further facilitate embedded development.

[More Information about Kuiper Linux](https://www.analog.com/en/resources/evaluation-hardware-and-software/embedded-development-software/kuiper-linux.html#software-overview)


### Overview

1. [Project directory selection](#project-directory-selection)
    - Choose a project directory
    - Clone this repo into that directory
2. [Kuiper Linux Setup](#kuiper-linux-setup)
    - Flash generic Kuiper Image to sd card
    - Build BOOT.BIN
    - Build device tree
    - Finalize Kuiper enabled sd card for booting on Bytepipe

### Attention: Run Linux natively or on a Virtual Machine for everything other than building HDL
Building system.dtb, u-boot.elf, and BOOT.BIN is much simpler when running a linux OS on your build machine, so most of the steps in this guide will only be accompanied by linux bash command line code.

If you are running a windows machine, command line code is available for cloning this repo and building hdl in Vivado. After performing those two tasks, I recommend you use a virtual machine to run Ubuntu v20.04 or v22.04.

## Project directory selection
1) Clone
Windows Command Prompt, Windows Git Bash, or Linux Terminal
(Download Git Bash for Windows - https://git-scm.com/install/windows)
```
git clone https://github.com/NextGenRF-Design-Inc/KuiperLinuxBytepipe.git
cd KuiperLinuxBytepipe
```
2) Setup workspace inside the cloned repository

Script: [setup-workspace.sh](sw/setup-workspace.sh) — `bash sw/setup-workspace.sh` after cloning.

Linux Terminal or Windows Git Bash (run from the repository directory):
```bash
export MY_APP_DIR="$(pwd -P)"
mkdir -p "$MY_APP_DIR/workspace"
```

Windows Command Prompt (run from the repository directory):
```bat
set "MY_APP_DIR=%CD%"
if not exist "%MY_APP_DIR%\workspace" mkdir "%MY_APP_DIR%\workspace"
```

`MY_APP_DIR` is the absolute path to the cloned `KuiperLinuxBytepipe` repository. The `workspace` subdirectory holds boot-assembly inputs and outputs; kernel and U-Boot builds run in their own source trees. In a new terminal, set `MY_APP_DIR` again to that same absolute path; when switching to Linux or a VM, use the repository path as seen by that environment.

Each section below assumes these paths are set in the current shell. The Linux SD-card steps also require `BOOT_PATH`, the absolute mount path of the flashed card's BOOT partition. Replace the placeholders before running:
```bash
export MY_APP_DIR="<absolute path to KuiperLinuxBytepipe>"
export BOOT_PATH="<absolute path to the SD card BOOT partition>"
mkdir -p "$MY_APP_DIR/workspace"
```

SD-card and workspace artifact copies use absolute paths anchored to these variables. Build sections explicitly select their working directory; run the steps within each section in order.

The linked scripts are alternatives to the manual commands in each section. They locate the repository from their own location, so they do not require `MY_APP_DIR` and can be invoked by absolute path from any directory. SD-card scripts accept `BOOT_PATH` as an argument or exported variable and require it to be a writable mount point. Run scripts with Bash on Linux (workspace setup also works in Git Bash); only the HDL build has a Windows Command Prompt script. Each script supports `--help`.

The build scripts do not install packages automatically. Run the dependency section first. The Linux and U-Boot scripts create fresh source checkouts and stop if those directories already exist, preserving existing work. For a retry, use the manual commands in the existing checkout or move it aside. The HDL Makefile requires a repository path without spaces.

For Xilinx builds, set `XILINX_ROOT` to the directory containing `Vivado/` and `Vitis/` (for example `/opt/Xilinx`). This guide requires version **2023.2**. Linux and U-Boot use the distribution's `aarch64-linux-gnu-` compiler by default; export `CROSS_COMPILE` to override it.

## Kuiper Linux Setup
Kuiper Linux is provided by Analog Devices and supports multiple evaluation platforms, including ZynqMP. This guide uses Bytepipe-specific boot files with the Kuiper root filesystem. Use the **2023_r2 Patch1** image from the [ADI release notes](https://wiki.analog.com/resources/tools-software/linux-software/adi-kuiper_images/release_notes) with the source versions below. The exact image used to validate the supplied binaries is not recorded in this repository; board-level compatibility still needs verification.

### Install build dependencies

Script: [install-build-deps.sh](sw/install-build-deps.sh).

Required for source builds on Ubuntu/Debian; prebuilt file copies do not need these packages. This script runs `sudo apt update` and installs the compiler, build tools, and libraries used below. Vivado/Vitis must be installed separately.

```bash
bash "$MY_APP_DIR/sw/install-build-deps.sh"
```

### 1. Flash generic Kuiper Image to sd card

Script: [install-kernel.sh](sw/install-kernel.sh) — `bash sw/install-kernel.sh prebuilt "$BOOT_PATH"`. This script performs the kernel copy after flashing; download and flashing remain manual. Use `stock` to select the image already on the card.

1) Download the 2023_r2 Patch1 Kuiper image from https://wiki.analog.com/resources/tools-software/linux-software/adi-kuiper_images/release_notes
![Kuiper_Download](kuiper_download_click.png)
2) Flash Kuiper Image to SD card. Use Kuiper Imager tool if possible.
3) Copy our modified ADI Linux Kernel to the root (or top-level) of sd card's BOOT partition.
```
export BOOT_PATH="<absolute path to the SD card BOOT partition>"
cp -f "$MY_APP_DIR/prebuilt/Image" "$BOOT_PATH/Image"
```
- If you want to start with a default ADI Linux Kernel Image, copy the zynqmp common Image file to root (or top-level) of sd card's BOOT partition.
```
export BOOT_PATH="<absolute path to the SD card BOOT partition>"
cp -f "$BOOT_PATH/zynqmp-common/Image" "$BOOT_PATH/Image"
```

Next, install **BOOT.BIN** and **system.dtb**, then complete [Finalize the SD card](#finalize-the-sd-card) to install the Bytepipe boot script.
Both can be acquired from this repo's [prebuilt](prebuilt/) directory or built from scratch.
BOOT.BIN, FSBL, and XSA must all match your Bytepipe model (3CG or 3EG). This repository supplies one shared system.dtb; its hardware layout must still match your board and HDL.

For a prebuilt BOOT.BIN, click on [Use Prebuilt BOOT.BIN](#2a-use-prebuilt-bootbin).

To compile a BOOT.BIN, continue to the "Compile BOOT.BIN" section or click on [Compile BOOT.BIN](#2b-compile-bootbin).

For a prebuilt system.dtb, click on [Use Prebuilt system.dtb](#use-prebuilt-systemdtb).

To compile system.dtb, click on [Compile system.dtb](#compile-systemdtb).

### 2a. Use Prebuilt BOOT.BIN

Script: [use-prebuilt-boot-bin.sh](sw/use-prebuilt-boot-bin.sh) — `bash sw/use-prebuilt-boot-bin.sh 3CG "$BOOT_PATH"`. Use `3EG` for that model.

1) Copy prebuilt BOOT.BIN to sd card
```
cp -f "$MY_APP_DIR/prebuilt/BOOT_3CG.BIN" "$BOOT_PATH/BOOT.BIN"
```
-or-
```
cp -f "$MY_APP_DIR/prebuilt/BOOT_3EG.BIN" "$BOOT_PATH/BOOT.BIN"
```

### 2b. Compile BOOT.BIN

Script: [compile-boot-bin.sh](sw/compile-boot-bin.sh) — `bash sw/compile-boot-bin.sh 3CG "$BOOT_PATH"`. Set `XILINX_ROOT` first. Use `3EG` for that model; prepare the matching XSA and U-Boot first.

1) Prepare a matching [XSA](#use-prebuilt-system_topxsa) and [U-Boot ELF](#use-prebuilt-u-bootelf) in the workspace (prebuilt or compiled), install [build dependencies](#install-build-dependencies), then move to the workspace directory
```
cd "$MY_APP_DIR/workspace"
```
2) FSBL files zynqmp_fsbl_3cg.elf and zynqmp_fsbl_3eg.elf are included in this repo's prebuilt directory.


Copy the one that matches your bytepipe model and rename the copy to "fsbl.elf".
```
cp -f ../prebuilt/zynqmp_fsbl_3cg.elf ./fsbl.elf
```
-or-
```
cp -f ../prebuilt/zynqmp_fsbl_3eg.elf ./fsbl.elf
```
3) Run [build_zynqmp_boot_bin_external_fsbl.sh](sw/build_zynqmp_boot_bin_external_fsbl.sh). build_zynqmp_boot_bin_external_fsbl.sh is a modified boot.bin build script that uses fsbl.elf from the current working directory (`workspace`). It regenerates `workspace/build_boot_bin` and `workspace/output_boot_bin` on each run. The original is found [here](https://raw.githubusercontent.com/analogdevicesinc/wiki-scripts/main/zynqmp_boot_bin/build_zynqmp_boot_bin.sh).

**system_top.xsa compile instructions are [here](#compile-system_topxsa) and prebuilt instructions are [here](#use-prebuilt-system_topxsa)**

**u-boot.elf compile instructions are [here](#compile-u-bootelf) and prebuilt instructions are [here](#use-prebuilt-u-bootelf)**

```
source "$XILINX_ROOT/Vivado/2023.2/settings64.sh"
source "$XILINX_ROOT/Vitis/2023.2/settings64.sh"
bash ../sw/build_zynqmp_boot_bin_external_fsbl.sh system_top.xsa u-boot.elf download
```
**Note:** `download` clones Xilinx ARM Trusted Firmware and builds `bl31.elf` locally using `aarch64-linux-gnu-gcc`. The source branch is selected from the detected Vitis version. Source the Vivado/Vitis 2023.2 environments before running the manual commands; the wrapper script does this using `XILINX_ROOT`.

4) Copy BOOT.BIN to sd card BOOT directory
```
cp -f "$MY_APP_DIR/workspace/output_boot_bin/BOOT.BIN" "$BOOT_PATH/BOOT.BIN"
```
### Use Prebuilt system.dtb

Script: [use-prebuilt-dtb.sh](sw/use-prebuilt-dtb.sh) — `bash sw/use-prebuilt-dtb.sh "$BOOT_PATH"`.

1) Copy prebuilt system.dtb to sd card
```
cp -f "$MY_APP_DIR/prebuilt/system.dtb" "$BOOT_PATH/system.dtb"
```

### Compile system.dtb

Script: [compile-dtb.sh](sw/compile-dtb.sh) — `bash sw/compile-dtb.sh "$BOOT_PATH"`. Install build dependencies first. This builds and copies the DTB to the card.

1) Install prerequisites:
```
sudo apt update
sudo apt install -y \
    git build-essential gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    bc bison flex libssl-dev libelf-dev device-tree-compiler \
    u-boot-tools
```
2) Clone ADI linux kernel repo
```
cd "$MY_APP_DIR"
git clone --depth 1 \
    --branch 2023_r2_p1 \
    https://github.com/analogdevicesinc/linux.git \
    linux-adi-2023-r2-p1

cd linux-adi-2023-r2-p1
```
3) Configure ZynqMP kernel tree
```
export ARCH=arm64
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"

make adi_zynqmp_defconfig
```
4) Copy your device tree source (.dts) file into the cloned repo
```
export LIN_DTS_DIR=arch/arm64/boot/dts/xilinx

cp ../sw/bytepipe.dts \
   "$LIN_DTS_DIR/bytepipe.dts"
```
5) Register your device tree in the device tree makefile.
```
chmod +x ../sw/add-zynqmp-dtb.sh
./../sw/add-zynqmp-dtb.sh bytepipe.dtb
```
6) Compile .dtb
```
make xilinx/bytepipe.dtb
```
7) Copy bytepipe.dtb to workspace directory as system.dtb
```
cp -f "$MY_APP_DIR/linux-adi-2023-r2-p1/arch/arm64/boot/dts/xilinx/bytepipe.dtb" "$MY_APP_DIR/workspace/system.dtb"
```
8) Copy system.dtb to the SD card BOOT partition
```bash
cp -f "$MY_APP_DIR/workspace/system.dtb" "$BOOT_PATH/system.dtb"
```

### Use Prebuilt system_top.xsa

Script: [use-prebuilt-xsa.sh](sw/use-prebuilt-xsa.sh) — `bash sw/use-prebuilt-xsa.sh 3CG`. Use `3EG` for that model.

1) Copy prebuilt system_top.xsa to workspace
```
cp -f "$MY_APP_DIR/prebuilt/3CG/system_top.xsa" "$MY_APP_DIR/workspace/system_top.xsa"
```
-or-
```
cp -f "$MY_APP_DIR/prebuilt/3EG/system_top.xsa" "$MY_APP_DIR/workspace/system_top.xsa"
```
**Note:** XSA is an archive. The existing BOOT.BIN builder specifically expects `system_top.xsa` and an exported `system_top.bit`. The HDL build exports that name by default; renaming an arbitrary XSA does not change the names inside it.

### Compile system_top.xsa

Script: [compile-xsa.sh](sw/compile-xsa.sh) — `bash sw/compile-xsa.sh 3CG`. Set `XILINX_ROOT` first. Use `3EG` for that model. Windows: [compile-xsa.cmd](sw/compile-xsa.cmd), invoked as `sw\compile-xsa.cmd 3CG`.

1) Source Vivado and Vitis

Windows Command Prompt:
```
set "XILINX_ROOT=C:\Xilinx"
call "%XILINX_ROOT%\Vivado\2023.2\settings64.bat"
vivado -version
echo %XILINX_VIVADO%
where vivado
call "%XILINX_ROOT%\Vitis\2023.2\settings64.bat"
vitis -version
echo %XILINX_VITIS%
where vitis
```

Linux Terminal:
```
export XILINX_ROOT="/opt/Xilinx"
source "$XILINX_ROOT/Vivado/2023.2/settings64.sh"
vivado -version
which vivado
source "$XILINX_ROOT/Vitis/2023.2/settings64.sh"
vitis -version
which vitis
```
2) Run HDL build makefile (examples use 3CG; substitute `xczu3eg` for 3EG). GNU Make and Git must be on PATH. The Linux Makefile uses `DEV` and lowercase `mode`; the Windows Makefile uses `DEVICE` and `MODE`.

Windows Command Prompt:
```
cd /d "%MY_APP_DIR%\workspace"
make -f ..\hdl\Makefile.windows DEVICE=xczu3cg MODE=lvds
```

Linux Terminal:
```
cd "$MY_APP_DIR/workspace"
make -f ../hdl/Makefile DEV=xczu3cg-sbva484-1-e mode=lvds XSA_NAME=system_top.xsa
```

### Use Prebuilt u-boot.elf

Script: [use-prebuilt-uboot.sh](sw/use-prebuilt-uboot.sh) — `bash sw/use-prebuilt-uboot.sh`.

1) Copy prebuilt u-boot.elf to workspace
```
cp -f "$MY_APP_DIR/prebuilt/u-boot.elf" "$MY_APP_DIR/workspace/u-boot.elf"
```

### Compile u-boot.elf

Script: [compile-uboot.sh](sw/compile-uboot.sh) — `bash sw/compile-uboot.sh`. Install build dependencies first.

1) Install build dependencies
```
sudo apt update
sudo apt install -y \
    git \
    build-essential \
    gcc-aarch64-linux-gnu \
    bc \
    bison \
    flex \
    device-tree-compiler \
    libssl-dev \
    libgnutls28-dev \
    libncurses-dev \
    python3 \
    python3-dev \
    python3-setuptools \
    python3-pyelftools \
    swig
```
2) Clone the Xilinx 2023.2 branch
```
cd "$MY_APP_DIR"
git clone \
    --branch xilinx-v2023.2 \
    --depth 1 \
    https://github.com/Xilinx/u-boot-xlnx.git
```
3) Enter u-boot directory
```
cd u-boot-xlnx
```
4) Set the cross-compilation environment
```
export ARCH=arm
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
```
5) Clean the source tree (only in a disposable build checkout; this removes generated configuration)
```
make distclean
```
6) Select the ZynqMP configuration
```
make xilinx_zynqmp_virt_defconfig
```
7) Copy your device tree source (.dts) file into the cloned repo
```
export DTS_DIR=arch/arm/dts/

cp ../sw/bytepipe_uboot.dts \
   "$DTS_DIR/bytepipe_uboot.dts"
```

8) Register device tree
```
chmod +x ../sw/register-uboot-dts.sh
./../sw/register-uboot-dts.sh bytepipe_uboot.dtb
```
9) Build u-boot
```
make -j"$(nproc)" \
    DEVICE_TREE=bytepipe_uboot
```
10) Copy u-boot.elf to workspace directory
```
cp -f "$MY_APP_DIR/u-boot-xlnx/u-boot.elf" "$MY_APP_DIR/workspace/u-boot.elf"
```


### Finalize the SD card

Script: [finalize-sd.sh](sw/finalize-sd.sh) — `bash sw/finalize-sd.sh "$BOOT_PATH"`.

Install the supplied Bytepipe `boot.scr` after the kernel, BOOT.BIN, and device tree. Its source is [sw/boot.txt](sw/boot.txt): it loads `Image` and `system.dtb` from `mmc 0:1`, uses `/dev/mmcblk0p2` as the root filesystem, and selects `ttyPS0` at 115200 baud. These assumptions must match the board's SD numbering. An existing U-Boot environment or higher-priority boot configuration can change which files are loaded; inspect the serial boot log if the expected script is not selected.

```bash
cp -f "$MY_APP_DIR/prebuilt/boot.scr" "$BOOT_PATH/boot.scr"
sync
```

Safely unmount/eject the card before removing it. Boot the Bytepipe from SD and verify the serial log and `iio_info` output. Source builds and file copies alone do not establish that the ADRV9002 or every peripheral works. The repository does not document the custom kernel's patch set or module installation procedure; use matching kernel modules in the root filesystem when changing kernels. The stock kernel option may lack Bytepipe-specific changes.
