@echo off
set input=img
set output=compressed
mkdir %output%

for %%f in (%input%\*.png %input%\*.jpg %input%\*.jpeg) do (
    cwebp -q 50 -m 6 -mt -metadata none "%%f" -o "%output%\%%~nf.webp"
)
