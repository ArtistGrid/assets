#!/bin/bash
set -euo pipefail

mkdir -p webp

export -f convert_one
convert_one() {
    in="$1"
    b="$(basename "$in" .png)"
    cwebp -q 50 -m 6 -mt -metadata none -resize 500 500 "$in" -o "webp/$b.webp"
}

find png -maxdepth 1 -type f -name "*.png" -print0 |
xargs -0 -P"$(nproc)" -I{} bash -c 'convert_one "$@"' _ "{}"
