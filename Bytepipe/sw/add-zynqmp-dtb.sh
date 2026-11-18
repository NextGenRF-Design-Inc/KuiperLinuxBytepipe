#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <filename.dtb> [path/to/Makefile]" >&2
    echo "Example: $0 bytepipe-custom.dtb" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 2
fi

dtb_name=$1
makefile=${2:-arch/arm64/boot/dts/xilinx/Makefile}

# Accept one exact DTB basename, not a path or an option.
if [[ $dtb_name == -* || $dtb_name == */* || $dtb_name != *.dtb ]]; then
    echo "Error: '$dtb_name' must be a .dtb filename without a directory path." >&2
    exit 2
fi

if [[ ! -f $makefile ]]; then
    echo "Error: Makefile not found: $makefile" >&2
    echo "Run this script from the Linux kernel repository root, or pass the Makefile path as argument 2." >&2
    exit 1
fi

entry='dtb-$(CONFIG_ARCH_ZYNQMP) += '"$dtb_name"
tmp_file=$(mktemp "${makefile}.tmp.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT

# Replace the first existing Kbuild entry for this exact DTB and remove any
# duplicates. If there is no match, append the new entry at the end.
awk -v target="$dtb_name" -v replacement="$entry" '
    $1 ~ /^dtb-/ && $2 == "+=" && $3 == target && NF == 3 {
        if (!found) {
            print replacement
            found = 1
        }
        next
    }
    { print }
    END {
        if (!found)
            print replacement
    }
' "$makefile" > "$tmp_file"

chmod --reference="$makefile" "$tmp_file"

if cmp -s "$makefile" "$tmp_file"; then
    echo "Already configured: $entry"
else
    mv "$tmp_file" "$makefile"
    echo "Updated $makefile: $entry"
fi
