# Kuiper Linux on Bytepipe

Prepare a Kuiper Linux SD card for Bytepipe 3CG or 3EG, using prebuilt files or building components from source.

Use Linux for SD-card preparation and software builds. HDL builds also support Windows. Source builds use Vivado/Vitis **2023.2**, ADI Linux **2023_r2_p1**, and Xilinx U-Boot **xilinx-v2023.2**.

## Setup

```bash
git clone https://github.com/NextGenRF-Design-Inc/KuiperLinuxBytepipe.git
cd KuiperLinuxBytepipe
bash sw/setup-workspace.sh
```

Run the commands below from this directory. Scripts locate the repository automatically and support `--help`.

## Prepare the SD card

Install flashing tools:

```bash
sudo apt update
sudo apt install -y curl python3 util-linux parted udev coreutils
```

Identify the SD card, then download, verify, flash, and install the kernel:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,RM,MOUNTPOINTS
bash sw/install-kernel.sh prebuilt --device /dev/sdX
```

**Replace `/dev/sdX` with the whole SD-card device. All data on it will be erased.** The script requires confirmation before writing.

Run the `export BOOT_PATH=...` command printed when installation finishes.

For an already flashed card:

```bash
export BOOT_PATH="/path/to/BOOT"
bash sw/install-kernel.sh prebuilt "$BOOT_PATH"
```

Use `stock` instead of `prebuilt` to select Kuiper’s stock kernel.

## Install boot files

Choose prebuilt or compiled files for each component. Each script performs its complete workflow.

| Boot file | Prebuilt | Compile |
|---|---|---|
| `BOOT.BIN` | [Use →](#prebuilt-bootbin) | [Build →](#compile-bootbin) |
| `system.dtb` | [Use →](#prebuilt-device-tree) | [Build →](#compile-device-tree) |

### Prebuilt BOOT.BIN

[Script](sw/use-prebuilt-boot-bin.sh) — use `3EG` instead of `3CG` where appropriate.

```bash
bash sw/use-prebuilt-boot-bin.sh 3CG "$BOOT_PATH"
```

### Prebuilt device tree

[Script](sw/use-prebuilt-dtb.sh)

```bash
bash sw/use-prebuilt-dtb.sh "$BOOT_PATH"
```

## Build from source

Install dependencies once:

```bash
bash sw/install-build-deps.sh
```

For HDL and BOOT.BIN builds, set the directory containing `Vivado/` and `Vitis/`:

```bash
export XILINX_ROOT="/opt/Xilinx"
```

### Compile BOOT.BIN

Prepare both inputs first:

| Build input | Prebuilt | Compile |
|---|---|---|
| `system_top.xsa` | `bash sw/use-prebuilt-xsa.sh 3CG` | `bash sw/compile-xsa.sh 3CG` |
| `u-boot.elf` | `bash sw/use-prebuilt-uboot.sh` | `bash sw/compile-uboot.sh` |

Then build and install BOOT.BIN:

```bash
bash sw/compile-boot-bin.sh 3CG "$BOOT_PATH"
```

Keep the XSA, FSBL, and BOOT.BIN model consistent. The script uses the supplied FSBL and builds ARM Trusted Firmware from source.

For Windows HDL builds:

```bat
set "XILINX_ROOT=C:\Xilinx"
sw\compile-xsa.cmd 3CG
```

### Compile device tree

[Script](sw/compile-dtb.sh) — builds and installs `system.dtb`.

```bash
bash sw/compile-dtb.sh "$BOOT_PATH"
```

## Finish and boot

Install `boot.scr` and flush pending writes:

```bash
bash sw/finalize-sd.sh "$BOOT_PATH"
```

Safely eject the card, boot Bytepipe from SD, and check the serial console at **115200 baud**. Run `iio_info` to inspect detected IIO devices.

## Build notes

- Linux and U-Boot build scripts require fresh source directories; they stop rather than overwrite existing checkouts.
- Keep the HDL project path free of spaces.
- BOOT.BIN builds recreate `workspace/build_boot_bin` and `workspace/output_boot_bin`.
- The supplied boot script expects BOOT at `mmc 0:1` and root at `/dev/mmcblk0p2`.
- The kernel and FSBL remain prebuilt. Kernel patch history and the original validation image are not documented; hardware compatibility and matching kernel modules still need verification.

[Kuiper release notes](https://wiki.analog.com/resources/tools-software/linux-software/adi-kuiper_images/release_notes)
