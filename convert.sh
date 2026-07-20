#!/bin/bash
set -euo pipefail

mkdir -p jpg webp jxl

if ! command -v vips >/dev/null 2>&1; then
    echo "ERROR: libvips (vips) not found; install libvips-tools" >&2
    exit 1
fi

if ! ls /usr/lib/vips-modules*/vips-jxl.so >/dev/null 2>&1; then
    echo "ERROR: libvips has no JXL support; install libvips with libjxl" >&2
    exit 1
fi

ls -1 og | grep -iE '\.(png|jpg|jpeg|webp)$' | jq -R -s 'split("\n") | map(select(length > 0))' > index.json

convert_one() {
    local in="$1" ext="$2" opts="$3"
    local base thumb out

    base="$(basename "$in")"
    base="${base%.*}"
    out="$ext/$base.$ext"

    [ -f "$out" ] && return

    thumb="$(mktemp --suffix=.jpg)"
    if ! vips thumbnail "$in" "$thumb" 500 --height 500 2>/dev/null; then
        echo "ERROR: failed to thumbnail $in" >&2
        rm -f "$thumb"
        return 1
    fi

    if ! vips copy "$thumb" "$out[$opts]" 2>/dev/null; then
        echo "ERROR: failed to convert $in -> $out" >&2
        rm -f "$thumb" "$out"
        return 1
    fi
    rm -f "$thumb"
}

convert_and_maybe_keep() {
    local in="$1" ext="$2" opts="$3"
    convert_one "$in" "$ext" "$opts"
}

export -f convert_one convert_and_maybe_keep

find og -maxdepth 1 -type f \( \
    -iname "*.png" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.webp" \
\) -print0 \
| xargs -0 -P "$(nproc)" -I{} bash -c 'set -e; convert_and_maybe_keep "{}" "jpg"  "Q=30"; convert_and_maybe_keep "{}" "webp" "Q=30"; convert_and_maybe_keep "{}" "jxl"  "Q=30,effort=9"'
