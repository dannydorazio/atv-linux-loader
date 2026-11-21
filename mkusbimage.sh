#!/bin/sh
#
# PURPOSE: Build a disk image with an atvrecv-flagged FAT32 partition that the Apple TV will boot from.
# Usage: mkusbimage.sh <output.img> <boot.efi> <Dummy.kext> <mach_kernel> <com.apple.Boot.plist> [kernel flags]
# SPDX-License-Identifier: GPL-2.0-only
#

set -e

out=$1
boot_efi=$2
kext=$3
kernel=$4
plist=$5
flags=$6

part_mib=256

case "$flags" in
    *[\&\<\>]*) echo "Kernel flags can't contain &, < or >" >&2; exit 1 ;;
esac

rm -f "$out"
truncate -s $((part_mib + 2))M "$out"
parted -s "$out" mklabel gpt mkpart boot fat32 1MiB $((part_mib + 1))MiB set 1 atvrecv on
mkfs.vfat -F 32 -n BOOT --offset 2048 "$out" $((part_mib * 1024)) > /dev/null

# Write files straight into the partition, so no loop device (or root) is needed
img="$out@@1M"
export MTOOLS_SKIP_CHECK=1
mmd -i "$img" ::/System ::/System/Library ::/System/Library/Extensions
mcopy -i "$img" "$boot_efi" ::/boot.efi
mcopy -i "$img" -s "$kext" ::/System/Library/Extensions/
mcopy -i "$img" "$kernel" ::/mach_kernel

# Fill in the Kernel Flags string
tmp=$(mktemp)
awk -v flags="$flags" '
    set { sub(/<string>.*<\/string>/, "<string>" flags "</string>"); set = 0 }
    /<key>Kernel Flags<\/key>/ { set = 1 }
    { print }
' "$plist" > "$tmp"
mcopy -i "$img" "$tmp" ::/com.apple.Boot.plist
rm -f "$tmp"

echo "Wrote $out"
