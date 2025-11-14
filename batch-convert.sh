#!/bin/bash

# --- Configuration ---
input_folder="png"
output_folder="webp"

# --- Check if cwebp command is available ---
if ! command -v cwebp &> /dev/null; then
    echo
    echo "ERROR: 'cwebp' not found in your system's PATH."
    echo "Please install the WebP command-line tools."
    echo "On Ubuntu/Debian: sudo apt install webp"
    echo "On Fedora/RHEL:   sudo dnf install libwebp-tools"
    echo "On Arch:          sudo pacman -S libwebp"
    echo
    read -p "Press Enter to exit..."
    exit 1
fi

# --- Create the output directory if it doesn't exist ---
if [ ! -d "$output_folder" ]; then
    echo "Creating directory: $output_folder"
    mkdir -p "$output_folder"
fi

echo
echo "Starting universal conversion and resizing..."
echo "Input folder:  $input_folder"
echo "Output folder: $output_folder"
echo

total=0
success=0
skipped=0
already_processed=0

# --- Loop through ALL FILES in the input folder, ignoring subdirectories ---
# Using find to get only files (not directories)
while IFS= read -r -d '' inputFile; do
    ((total++))

    # Extract filename without path
    filename=$(basename "$inputFile")
    # Extract filename without extension
    filename_noext="${filename%.*}"

    # Define the output path
    outputFile="$output_folder/${filename_noext}.webp"

    # --- Check if output file already exists ---
    if [ -f "$outputFile" ]; then
        echo "[$total] Already processed: \"$filename\" - Skipping"
        ((already_processed++))
    else
        echo "[$total] Processing: \"$filename\""

        # --- cwebp command with resizing ---
        if cwebp -q 50 -m 6 -mt -metadata none -resize 500 500 "$inputFile" -o "$outputFile" &> /dev/null; then
            echo "  -> Success: Converted and resized to \"${filename_noext}.webp\""
            ((success++))
        else
            echo "  -> Skipped: \"$filename\" is not a supported image format or is corrupted."
            ((skipped++))
        fi
    fi
done < <(find "$input_folder" -maxdepth 1 -type f -print0)

echo
echo "---"
echo "Done."
echo
echo "--- Summary ---"
echo "Total files found:      $total"
echo "Successfully converted: $success"
echo "Already processed:      $already_processed"
echo "Skipped or failed:      $skipped"
echo "---"
echo
read -p "Press Enter to exit..."
