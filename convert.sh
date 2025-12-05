#!/bin/bash
set -euo pipefail

mkdir -p webp

find png -maxdepth 1 -type f \( \
    -iname "*.png" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.webp" -o \
    -iname "*.avif" \
\) -print0 \
| xargs -0 -P "$(nproc)" -I{} bash -c '
in="$1"
name="$(basename "$in")"
base="${name%.*}"
cwebp -q 50 -m 6 -mt -metadata none -resize 500 500 "$in" -o "webp/$base.webp"
' _ "{}"
