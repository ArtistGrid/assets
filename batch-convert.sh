#!/bin/bash

input_folder="png"
output_folder="webp"

if ! command -v cwebp >/dev/null 2>&1; then
    exit 1
fi

mkdir -p "$output_folder"

total=0
success=0
skipped=0
already_processed=0

while IFS= read -r -d '' inputFile; do
    ((total++))
    filename=$(basename "$inputFile")
    filename_noext="${filename%.*}"
    outputFile="$output_folder/${filename_noext}.webp"

    if [ -f "$outputFile" ]; then
        ((already_processed++))
    else
        if cwebp -q 50 -m 6 -mt -metadata none -resize 500 500 "$inputFile" -o "$outputFile" >/dev/null 2>&1; then
            ((success++))
        else
            ((skipped++))
        fi
    fi
done < <(find "$input_folder" -maxdepth 1 -type f -print0)

exit 0
