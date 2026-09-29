#!/bin/bash
set -uo pipefail

SIZE="${SIZE:-500}"
WEBP_Q="${WEBP_Q:-35}"
JPG_Q="${JPG_Q:-40}"
AVIF_Q="${AVIF_Q:-30}"
JXL_D="${JXL_D:-5.0}"
AVIF_SPEED="${AVIF_SPEED:-0}"
JXL_EFFORT="${JXL_EFFORT:-10}"
FORMATS="${FORMATS:-avif jxl webp jpg}"
JOBS="${JOBS:-$(nproc)}"

for c in vips cjxl avifenc cwebp jq; do
    command -v "$c" >/dev/null 2>&1 || { echo "ERROR: $c not found" >&2; exit 1; }
done

for f in $FORMATS; do mkdir -p "$f"; done

find og -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -printf '%f\n' | sort | jq -R -s 'split("\n") | map(select(length > 0))' > index.json

run() {
    local o
    o=$("$@" 2>&1) || { printf 'ERROR: command failed: %s\n%s\n' "$*" "$o" >&2; return 1; }
}

process_one() {
    local in="$1" base tmp fmt out part o x b
    base="$(basename "$in")"; base="${base%.*}"

    local todo=()
    for fmt in $FORMATS; do [ -s "$fmt/$base.$fmt" ] || todo+=("$fmt"); done
    [ ${#todo[@]} -eq 0 ] && return 0

    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

    run vips thumbnail "$in" "$tmp/t.png[compression=1,keep=none]" "$SIZE" \
        --height "$SIZE" --size down --export-profile srgb \
    && run vips flatten "$tmp/t.png" "$tmp/ref.png[compression=1,keep=none]" --background 255 \
    || { echo "ERROR: thumbnail failed: $in" >&2; return 1; }

    b=$(vips header -f bands "$tmp/ref.png" 2>/dev/null)
    if [ "$b" = "4" ]; then
        run vips extract_band "$tmp/ref.png" "$tmp/ref3.png[compression=1,keep=none]" 0 --n 3 \
            && mv -f "$tmp/ref3.png" "$tmp/ref.png"
    elif [ "$b" = "2" ]; then
        run vips extract_band "$tmp/ref.png" "$tmp/ref3.png[compression=1,keep=none]" 0 --n 1 \
            && mv -f "$tmp/ref3.png" "$tmp/ref.png"
    fi

    for fmt in "${todo[@]}"; do
        out="$fmt/$base.$fmt"
        part="$tmp/out.$fmt"
        case "$fmt" in
            avif)
                o=$(avifenc -s "$AVIF_SPEED" -j 1 -d 10 -y 420 -q "$AVIF_Q" \
                        -a tune=ssim -a enable-qm=1 \
                        "$tmp/ref.png" "$part" 2>&1) \
                || {
                    printf 'WARN: avif full flags failed for %s:\n%s\n' "$in" "$o" >&2
                    run avifenc -s "$AVIF_SPEED" -j 1 -d 10 -y 420 -q "$AVIF_Q" "$tmp/ref.png" "$part"
                } ;;
            jxl)
                x=""; [ "$JXL_EFFORT" -ge 10 ] && x="--allow_expert_options"
                run cjxl "$tmp/ref.png" "$part" -d "$JXL_D" -e "$JXL_EFFORT" \
                    --num_threads=1 --quiet $x ;;
            webp)
                run cwebp -quiet -q "$WEBP_Q" -m 6 -pass 10 -sharp_yuv -af -metadata none \
                    "$tmp/ref.png" -o "$part" ;;
            jpg)
                run vips copy "$tmp/ref.png" "$part[Q=$JPG_Q,mozjpeg,subsample_mode=on,keep=none]" ;;
        esac || { echo "ERROR: $fmt failed: $in" >&2; continue; }

        mv -f "$part" "$out"
    done
}

export -f run process_one
export SIZE WEBP_Q JPG_Q AVIF_Q JXL_D AVIF_SPEED JXL_EFFORT FORMATS

find og -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 \
    | xargs -0 -P "$JOBS" -n 1 bash -c 'process_one "$1"' _

echo "done."
