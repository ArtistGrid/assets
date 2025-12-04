#!/bin/bash

mkdir -p webp

find png -maxdepth 1 -type f \
| while read -r f; do
    base=$(basename "$f" .png)
    out="webp/$base.webp"
    if [ ! -f "$out" ]; then
        printf '%s\0' "$f"
    fi
done \
| xargs -0 -I{} -P "$(nproc)" bash -c '
in="$1"
n=$(basename "$in")
b="${n%.*}"
cwebp -q 50 -m 6 -mt -metadata none -resize 500 500 "$in" -o "webp/$b.webp" >/dev/null 2>&1
' _ {}
