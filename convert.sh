#!/bin/bash
set -uo pipefail

SIZE="${SIZE:-500}"
WEBP_Q="${WEBP_Q:-35}"
JPG_Q="${JPG_Q:-40}"
AVIF_Q="${AVIF_Q:-30}"
JXL_D="${JXL_D:-5.0}"
AVIF_SPEED="${AVIF_SPEED:-0}"
JXL_EFFORT="${JXL_EFFORT:-9}"
FORMATS="${FORMATS:-avif jxl webp jpg}"
JOBS="${JOBS:-$(nproc)}"
FORCE="${FORCE:-0}"

# Parallelism already comes from xargs -P "$JOBS" below, and avifenc/cjxl
# are pinned to 1 thread each — keep vips single-threaded too so N jobs
# don't spawn N thread pools each (N x N oversubscription).
export VIPS_CONCURRENCY=1

# Installed cjxl builds accept --effort 1-9 only; clamp higher values
# (e.g. from the environment) so jxl encodes don't fail outright.
if [ "${JXL_EFFORT}" -gt 9 ] 2>/dev/null; then
    JXL_EFFORT=9
fi

for c in vips vipsheader cjxl avifenc cwebp jq; do
    command -v "$c" >/dev/null 2>&1 || { echo "ERROR: $c not found" >&2; exit 1; }
done

for f in $FORMATS; do mkdir -p "$f"; done

find og -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' \) \
    -printf '%f\n' | sort | jq -R -s 'split("\n") | map(select(length > 0))' > index.json

# Clean up any previously generated outputs whose source file was deleted from og
valid_bases="$(jq -r '.[] | split(".")[0:-1] | join(".")' index.json | sort -u)"
for fmt in $FORMATS; do
    find "$fmt" -maxdepth 1 -type f -name "*.$fmt" -printf '%f\n' | sed "s/\.$fmt$//" | sort -u \
        | comm -23 - <(printf '%s\n' "$valid_bases") \
        | while IFS= read -r b; do
            [ -n "$b" ] && rm -f "$fmt/$b.$fmt"
        done
done

run() {
    local o
    o=$("$@" 2>&1) || { printf 'ERROR: command failed: %s\n%s\n' "$*" "$o" >&2; return 1; }
}

process_one() {
    local in="$1" base tmp fmt out part o b
    base="$(basename "$in")"; base="${base%.*}"

    local todo=()
    for fmt in $FORMATS; do
        if [ "$FORCE" = "1" ] || [ ! -s "$fmt/$base.$fmt" ]; then
            todo+=("$fmt")
        fi
    done
    [ ${#todo[@]} -eq 0 ] && return 0

    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp:-}"' EXIT RETURN

    run vips thumbnail "$in" "$tmp/t.png[compression=1,keep=none]" "$SIZE" \
        --height "$SIZE" --size down --export-profile srgb \
        || { echo "ERROR: thumbnail failed: $in" >&2; return 1; }

    b=$(vipsheader -f bands "$tmp/t.png" 2>/dev/null || echo "")
    if [ "$b" = "4" ] || [ "$b" = "2" ]; then
        run vips flatten "$tmp/t.png" "$tmp/ref.png[compression=1,keep=none]" --background 255 \
            || { echo "ERROR: flatten failed: $in" >&2; return 1; }
    else
        mv -f "$tmp/t.png" "$tmp/ref.png"
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
                run cjxl "$tmp/ref.png" "$part" -d "$JXL_D" -e "$JXL_EFFORT" \
                    --num_threads=1 --quiet ;;
            webp)
                run cwebp -quiet -q "$WEBP_Q" -m 6 -pass 10 -sharp_yuv -af -metadata none \
                    "$tmp/ref.png" -o "$part" ;;
            jpg)
                run vips copy "$tmp/ref.png" "$part[Q=$JPG_Q,optimize_coding=true,subsample_mode=on,keep=none]" ;;
        esac || { echo "ERROR: $fmt failed: $in" >&2; continue; }

        mv -f "$part" "$out"
    done
}

export -f run process_one
export SIZE WEBP_Q JPG_Q AVIF_Q JXL_D AVIF_SPEED JXL_EFFORT FORMATS FORCE

find og -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' \) -print0 \
    | xargs -0 -P "$JOBS" -n 1 bash -c 'process_one "$1"' _

echo "done."
