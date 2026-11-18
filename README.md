# Kuiper Linux on Bytepipe

Preparing and booting NextGenRF Bytepipe hardware. One top-level folder per
product, because the two differ in SoC, radio and boot medium, and threading a
model flag through every script would hide more than it shares.

| Folder | Product | Covers |
|---|---|---|
| [`Bytepipe/`](Bytepipe/README.md) | Bytepipe 3CG / 3EG | SD-card preparation, prebuilt boot files, building BOOT.BIN, U-Boot, the device tree and the HDL from source |
| [`BytepipeX/`](BytepipeX/README.md) | BytepipeX (ADRV9009 over JESD204B) | boot layout and boot-medium selection, what the boot partition holds, and what the shipped image provides |

`LICENSE` at the root covers both.

## Which one am I holding?

The two are not interchangeable and the scripts will tell you so: the Bytepipe
workflow scripts accept only `3CG` or `3EG` as a model and fail on anything
else. If your board carries an ADRV9009 and boots from eMMC, you are on a
BytepipeX and want `BytepipeX/`.

## Start here

- **Bytepipe 3CG/3EG, new SD card** → [`Bytepipe/README.md`](Bytepipe/README.md).
  Everything in that folder is self-contained: run its scripts from inside
  `Bytepipe/`, and they resolve their own paths.
- **BytepipeX** → [`BytepipeX/README.md`](BytepipeX/README.md). Boot layout and
  image facts are documented; the preparation scripts and prebuilt artifacts
  that `Bytepipe/` has are not there yet, and the file says so plainly rather
  than implying they exist.

## A note on the layout

Everything under `Bytepipe/` moved there unchanged. The scripts resolve their
own location rather than the repository root, so they did not need editing —
only the clone recipe did, because you now work from the product folder:

```bash
git clone https://github.com/NextGenRF-Design-Inc/KuiperLinuxBytepipe.git
cd KuiperLinuxBytepipe/Bytepipe
```
