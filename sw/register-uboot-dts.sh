#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <custom.dts|custom.dtb> [path/to/arch/arm/dts/Makefile]" >&2
    echo "Example: $0 bytepipe-custom.dts" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 2
fi

input_name=$1
makefile=${2:-arch/arm/dts/Makefile}

# The source and output must be basenames within U-Boot's arch/arm/dts tree.
if [[ $input_name == -* || $input_name == */* ]]; then
    echo "Error: '$input_name' must be a filename without a directory path." >&2
    exit 2
fi

case $input_name in
    *.dts) dtb_name=${input_name%.dts}.dtb ;;
    *.dtb) dtb_name=$input_name ;;
    *)
        echo "Error: '$input_name' must end in .dts or .dtb." >&2
        exit 2
        ;;
esac

if [[ ! -f $makefile ]]; then
    echo "Error: U-Boot DTS Makefile not found: $makefile" >&2
    echo "Run this script from the u-boot-xlnx repository root, or pass the Makefile path as argument 2." >&2
    exit 1
fi

dts_path=$(dirname "$makefile")/${dtb_name%.dtb}.dts
if [[ ! -f $dts_path ]]; then
    echo "Warning: corresponding DTS is not present yet: $dts_path" >&2
fi

entry='dtb-$(CONFIG_ARCH_ZYNQMP) += '"$dtb_name"
tmp_file=$(mktemp "${makefile}.tmp.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT

# Remove this exact DTB from any conventional standalone or multiline list,
# then insert one normalized registration after the Makefile's header comments.
# Keeping it near the top ensures it is present before the dtbs prerequisite
# list is expanded near the end of Xilinx U-Boot's arch/arm/dts/Makefile.
awk -v target="$dtb_name" -v replacement="$entry" '
    { lines[NR] = $0 }

    END {
        # Mark conventional exact registrations for removal. This covers:
        #   dtb-$(...) += custom.dtb
        #   custom.dtb \
        #   custom.dtb
        for (line_no = 1; line_no <= NR; line_no++) {
            content = lines[line_no]
            sub(/^[[:space:]]+/, "", content)
            count = split(content, fields, /[[:space:]]+/)
            found = 0
            for (field_no = 1; field_no <= count; field_no++) {
                token = fields[field_no]
                sub(/\\$/, "", token)
                if (token == target)
                    found = 1
            }

            if (!found)
                continue

            # A standalone assignment containing only the exact DTB.
            if (fields[1] ~ /^dtb-/ && fields[2] == "+=" && \
                fields[3] == target && count == 3) {
                remove[line_no] = 1
                continue
            }

            # A normal item in a backslash-continued dtb list.
            clean_first = fields[1]
            sub(/\\$/, "", clean_first)
            if (clean_first == target && count <= 2) {
                remove[line_no] = 1

                # If this was the final item, remove the continuation marker
                # from the previous retained line so it does not absorb the
                # next Makefile statement.
                if (lines[line_no] !~ /\\[[:space:]]*$/) {
                    previous = line_no - 1
                    while (previous > 0 && remove[previous])
                        previous--
                    sub(/[[:space:]]*\\[[:space:]]*$/, "", lines[previous])
                }
            }
        }

        # Insert after the initial blank/comment header and before the first
        # actual Makefile statement.
        inserted = 0
        for (line_no = 1; line_no <= NR; line_no++) {
            if (!inserted && !remove[line_no] && \
                lines[line_no] !~ /^[[:space:]]*($|#)/) {
                print replacement
                inserted = 1
            }

            if (!remove[line_no])
                print lines[line_no]
        }

        if (!inserted)
            print replacement
    }
' "$makefile" > "$tmp_file"

chmod --reference="$makefile" "$tmp_file"

if cmp -s "$makefile" "$tmp_file"; then
    echo "Already registered: $dtb_name"
else
    mv "$tmp_file" "$makefile"
    echo "Updated $makefile: $entry"
fi
