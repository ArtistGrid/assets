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
| while IFS= read -r -d '' in; do
    name="$(basename "$in")"
    base="${name%.*}"
    out="webp/$base.webp"

    # Skip if already converted
    if [[ ! -f "$out" ]]; then
        printf '%s\0' "$in"
    fi
done \
| xargs -0 -P "$(nproc)" -I{} bash -c '
in="$1"
name="$(basename "$in")"
base="${name%.*}"

# IMPORTANT: -quiet prevents encoder spam that causes exit 124
cwebp -quiet -q 50 -m 6 -mt -metadata none -resize 500 500 "$in" -o "webp/$base.webp"
' _ "{}"
