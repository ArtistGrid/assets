@echo off
setlocal enabledelayedexpansion

REM --- Configuration ---
set "input_folder=png"
set "output_folder=webp"

REM --- Check if cwebp command is available ---
where cwebp >nul 2>nul
if not %errorlevel% equ 0 (
    echo.
    echo ERROR: 'cwebp.exe' not found in your system's PATH.
    echo Please install the WebP command-line tools and ensure
    echo cwebp.exe is accessible via your PATH environment variable.
    echo.
    pause
    goto :eof
)

REM --- Create the output directory if it doesn't exist ---
if not exist "%output_folder%" (
    echo Creating directory: %output_folder%
    mkdir "%output_folder%"
)

echo.
echo Starting universal conversion and resizing...
echo Input folder:  %input_folder%
echo Output folder: %output_folder%
echo.

set /a "total=0"
set /a "success=0"
set /a "skipped=0"

REM --- Loop through ALL FILES in the input folder, ignoring subdirectories ---
REM The 'dir /b /a-d' command provides a clean list of filenames.
for /f "delims=" %%f in ('dir /b /a-d "%input_folder%\*.*"') do (
    set /a "total+=1"
    echo [!total!] Processing: "%%f"
    
    REM --- Define the full input and output paths ---
    set "inputFile=%input_folder%\%%f"
    set "outputFile=%output_folder%\%%~nf.webp"

    REM --- cwebp command with resizing ---
    REM This will attempt to convert any file. If cwebp doesn't recognize
    REM the format, it will return an error, which we will catch.
    REM We redirect normal output (>nul) and error output (2>nul) to keep the log clean.
    cwebp -q 50 -m 6 -mt -metadata none -resize 500 500 "!inputFile!" -o "!outputFile!" >nul 2>nul
    
    REM --- Check if the command was successful ---
    if !errorlevel! equ 0 (
        echo   -> Success: Converted and resized to "%%~nf.webp"
        set /a "success+=1"
    ) else (
        echo   -> Skipped: "%%f" is not a supported image format or is corrupted.
        set /a "skipped+=1"
    )
)

echo.
echo ---
echo Done.
echo.
echo --- Summary ---
echo Total files found:   !total!
echo Successfully converted: !success!
echo Skipped or failed:    !skipped!
echo ---
echo.
pause