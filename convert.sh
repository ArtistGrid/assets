#!/bin/bash
set -euo pipefail

mkdir -p jpg webp jxl

ls -1 og | grep -iE '\.(png|jpg|jpeg|webp)$' | jq -R -s 'split("\n") | map(select(length > 0))' > index.json

convert_and_maybe_keep() {
    local in="$1" ext="$2" flags="$3"
    local base src_ext out in_size out_size

    base="$(basename "$in")"
    base="${base%.*}"
    src_ext="${in##*.}"
    out="$ext/$base.$ext"

    [ "$ext" = "$src_ext" ] && return
    [ -f "$out" ] && return

    magick "$in" -resize 500x500 -strip $flags "$out"
}

export -f convert_and_maybe_keep

find og -maxdepth 1 -type f \( \
    -iname "*.png" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.webp" \
\) -print0 \
| xargs -0 -P "$(nproc)" -I{} bash -c '
convert_and_maybe_keep "{}" "jpg"  "-quality 30"
convert_and_maybe_keep "{}" "webp" "-quality 30 -define webp:method=6"
convert_and_maybe_keep "{}" "jxl"  "-quality 30 -define jxl:effort=9"
'
