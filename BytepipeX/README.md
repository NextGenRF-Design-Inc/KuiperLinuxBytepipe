# Kuiper Linux on BytepipeX

For Bytepipe 3CG/3EG, see [`../Bytepipe/README.md`](../Bytepipe/README.md).

BytepipeX is a Zynq UltraScale+ MPSoC carrying an ADRV9009 over JESD204B. It
differs from Bytepipe 3CG/3EG in two ways that matter before you touch
anything: it normally boots from **eMMC** rather than an SD card, and its boot
partition uses an **extlinux** configuration rather than a `boot.scr`.

> **Scope.** This file documents the boot layout and what the shipped image
> provides. The preparation scripts and prebuilt artifacts that `Bytepipe/`
> has are **not here yet** — see [What is not here yet](#what-is-not-here-yet).
> Nothing below is a stub: every statement was read from a boot package
> captured from a running BytepipeX.

## Boot medium

Two boot sources, selected by the **boot-mode pins** on the carrier, not by
software:

- **eMMC** — the normal case for a provisioned board.
- **SD card** — used for provisioning and for recovery.

Because the selection is physical, a board that will not boot from eMMC can be
brought up from SD without touching the eMMC contents, which is the basis of
the recovery path.

## What the boot partition holds

The first partition is FAT32, labelled `BPXBOOT`, and holds exactly these:

```
BOOT.BIN              FSBL + PMU firmware + ATF + U-Boot + the bitstream
Image                 the kernel
system.dtb            the device tree
extlinux/extlinux.conf   the boot entry: kernel, FDT and kernel command line
uEnv.txt              U-Boot environment, including a bootargs line
```

`BOOT.BIN` carries the bitstream, so replacing it reprograms the PL. Note that
it must be built with a BIF that includes the `system.dtb` partition; one built
without it stops in U-Boot.

## Partition layout

MBR (`dos`), disk identifier `0x9009beef`, 512-byte sectors:

| Partition | Start (sectors) | Size (sectors) | Type | Label | PARTUUID |
|---|---|---|---|---|---|
| p1 | 2048 | 2097152 (1 GiB) | `c` FAT32 LBA, **bootable** | `BPXBOOT` | `9009beef-01` |
| p2 | 2099200 | 60061696 (~28.6 GiB) | `83` Linux ext4 | `rootfs` | `9009beef-02` |

`/etc/fstab` mounts **by PARTUUID**, not by device node, so the names above are
load-bearing: a root filesystem written without them boots to nothing even
though every file is present. The bootable flag on p1 matters too — U-Boot's
`scan_dev_for_boot_part` relies on it.

## Which file supplies the kernel command line

**`extlinux/extlinux.conf` is the file in effect.** This is worth stating
because `uEnv.txt` also contains a `bootargs=` line, and it is reasonable to
assume U-Boot prefers it. It does not.

Confirm it yourself on a running board rather than trusting either file:

```bash
cat /proc/cmdline
```

Compare that against both. The running command line reproduces the
`extlinux.conf` `APPEND` line **in exactly its argument order**, while
`uEnv.txt` orders the same arguments differently — which is what identifies the
source unambiguously. Edit `extlinux.conf` to change the command line; edit
`uEnv.txt` as well if you want the two to agree, but do not expect editing only
`uEnv.txt` to have any effect.

### Display mode is a boot-time decision

The DisplayPort output takes its mode from the kernel command line, because
Xorg runs the `fbdev` driver and so inherits whatever mode DRM set at boot.
`xrandr` reports a single mode with `minimum` equal to `maximum` — there is
nothing to switch to at run time. To pin a mode, add to the `APPEND` line:

```
video=<connector>:<width>x<height>@<refresh>
```

Two traps are worth knowing before you use it:

- **A `video=` pin describes the monitor, not the board.** Pin a mode for one
  display and attach another that cannot show it, and you get a black screen
  with no indication of why. Prefer leaving it unpinned and letting EDID
  choose, unless you have a specific reason.
- **Do not switch Xorg to the `modesetting` driver** to get run-time mode
  changes. The DRM device advertises a cursor dimension of 2147483647, and
  Xorg does not survive trying to allocate it.

## What the shipped image provides

Read from the image itself:

- **A 32-bit ARM (`armhf`) userspace**, on a 64-bit SoC. The loader is
  `ld-linux-armhf.so.3` and the multiarch directory is
  `/usr/lib/arm-linux-gnueabihf`; there is no `aarch64-linux-gnu` tree at all.
  **Build with an `armhf` cross-toolchain, not `aarch64`** — this is the
  easiest thing on this page to get wrong, because the SoC invites the opposite
  assumption.
- **libiio 0.26**, present in two places: the packaged library under
  `/usr/lib/arm-linux-gnueabihf/`, and a build from source under
  `/usr/local/src/libiio/build/`. Same soname and version, so which one an
  application resolves against depends on its link and loader paths. If you see
  behaviour that disagrees with the libiio you think you are using, check which
  copy is actually loaded.
- **`iiod` starts at boot** (`iiod.service`, along with
  `iiod_context_attr.service`), so a remote `iio_info -u ip:<address>` works
  against a freshly booted board without starting anything by hand.
- **Python 3.9.**
- **No `/lib/modules` tree**, so the radio and JESD drivers are built into the
  kernel rather than loadable. `modprobe` is not how you influence them;
  the device tree is.

## What is not here yet

Stated plainly so nobody goes looking:

- **No prebuilt boot artifacts** in this folder. `Bytepipe/prebuilt/` has
  BOOT.BIN, kernel, device tree and XSA per model; there is no BytepipeX
  equivalent committed here.
- **No preparation scripts.** `Bytepipe/sw/` has the download/flash/build
  workflow; BytepipeX provisioning is not scripted in this repo.
- **No HDL project or board files** for BytepipeX.
- **The kernel version is not recorded here.** It could not be read from the
  root filesystem, because there is no `/lib/modules` tree to read it from.

Until those exist, treat this file as the boot-layout reference it is, not as a
provisioning guide.
