{ pkgs, lib, ... }:
with lib;
with lib.campground;

pkgs.writeShellApplication {
  name = "ocr-script";
  runtimeInputs = [ pkgs.bat pkgs.imagemagick pkgs.ghostscript pkgs.tesseract ];
  text = ''
    [ -z "$1" ] && echo "Usage: $0 <pdf-file-path>" && exit 1
    PDF_FILE="$1"
    BASE_NAME="''${PDF_FILE%.*}"
    IMG_PATTERN="''${BASE_NAME}-%04d.png"
    TXT_FILE="''${BASE_NAME}.txt"

    # Convert PDF to PNG
    magick -density 300 "$PDF_FILE" "$IMG_PATTERN" || { echo "Conversion failed."; exit 1; }

    # Run OCR on each generated PNG and append output to TXT_FILE
    for IMG_FILE in "''${BASE_NAME}"-*.png; do
      tesseract "$IMG_FILE" stdout >> "$TXT_FILE" || { echo "OCR failed."; exit 1; }
    done

    # Clean up PNG files
    rm "''${BASE_NAME}"-*.png

    # Display the output file
    bat -p "$TXT_FILE"
  '';
}
