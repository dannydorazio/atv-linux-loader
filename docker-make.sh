#!/usr/bin/env bash
#
# PURPOSE: Run make inside the Linux build container.
# Usage: ./docker-make.sh [make arguments], e.g. ./docker-make.sh KERNEL=/path/to/vmlinuz INITRAMFS=/path/to/initrd
# SPDX-License-Identifier: GPL-2.0-only
#

set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
image=atv-linux-loader-build

docker build -q -t "$image" "$repo" > /dev/null

mounts=()
args=()
for arg in "$@"; do
    case "$arg" in
        KERNEL=*|INITRAMFS=*)
            # Files outside the repo aren't visible in the container, so mount each one read-only
            var="${arg%%=*}"
            path="${arg#*=}"
            abs="$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
            mounts+=(-v "$abs:/inputs/$var/$(basename "$path"):ro")
            args+=("$var=/inputs/$var/$(basename "$path")")
            ;;
        *)
            args+=("$arg")
            ;;
    esac
done

exec docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$repo:/src" \
    ${mounts[@]+"${mounts[@]}"} "$image" make ${args[@]+"${args[@]}"}
