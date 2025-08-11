@echo off
setlocal enabledelayedexpansion

REM --- Configuration ---
set "input_folder=png"
set "output_folder=webp"

REM --- Create the output directory if it doesn't exist ---
if not exist "%output_folder%" (
    echo Creating directory: %output_folder%
    mkdir "%output_folder%"
)

echo.
echo Starting conversion and resizing...
echo.

REM --- Loop through all PNG files in the input folder ---
for %%f in ("%input_folder%\*.png") do (
    echo Processing: "%%~nxf"
    
    REM --- cwebp command with resizing ---
    cwebp -q 50 -m 6 -mt -metadata none -resize 500 500 "%%f" -o "%output_folder%\%%~nf.webp"
)

echo.
echo ---
echo Done.
echo.
pause