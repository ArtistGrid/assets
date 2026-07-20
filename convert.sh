#!/bin/bash
set -euo pipefail

mkdir -p jpg webp jxl

if command -v magick >/dev/null 2>&1; then
    MAGICK="magick"
elif command -v convert >/dev/null 2>&1; then
    MAGICK="convert"
else
    echo "ERROR: ImageMagick (magick/convert) not found" >&2
    exit 1
fi

if ! "$MAGICK" -list format 2>/dev/null | grep -qi 'JXL.*rw'; then
    echo "ERROR: ImageMagick has no JXL delegate; install libjxl-tools" >&2
    exit 1
fi

ls -1 og | grep -iE '\.(png|jpg|jpeg|webp)$' | jq -R -s 'split("\n") | map(select(length > 0))' > index.json

convert_and_maybe_keep() {
    local in="$1" ext="$2" flags="$3"
    local base out

    base="$(basename "$in")"
    base="${base%.*}"
    out="$ext/$base.$ext"

    [ -f "$out" ] && return

    if ! "$MAGICK" "$in" -resize 500x500\> -strip $flags "$out"; then
        echo "ERROR: failed to convert $in -> $out" >&2
        return 1
    fi

    if [ "$ext" = "jxl" ]; then
        local magic
        magic="$(xxd -p -l4 "$out" 2>/dev/null)"
        if [ "${magic:0:4}" != "ff0a" ]; then
            echo "ERROR: $out is not a valid JXL (magic=$magic); JXL delegate likely missing" >&2
            rm -f "$out"
            return 1
        fi
    fi
}

export -f convert_and_maybe_keep

find og -maxdepth 1 -type f \( \
    -iname "*.png" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.webp" \
\) -print0 \
| xargs -0 -P "$(nproc)" -I{} bash -c 'set -e; convert_and_maybe_keep "{}" "jpg"  "-quality 30"; convert_and_maybe_keep "{}" "webp" "-quality 30 -define webp:method=6"; convert_and_maybe_keep "{}" "jxl"  "-quality 30 -define jxl:effort=9"'
