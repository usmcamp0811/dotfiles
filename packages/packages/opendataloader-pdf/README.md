# OpenDataLoader PDF

A Nix package for [OpenDataLoader PDF](https://github.com/opendataloader-project/opendataloader-pdf) - a PDF parser designed for AI data extraction and accessibility.

## Features

- #1 in benchmarks (0.90 overall accuracy)
- Extracts Markdown, JSON (with bounding boxes), and HTML from PDFs
- Built-in OCR for scanned PDFs (80+ languages)
- Complex table extraction
- LaTeX formula extraction
- AI-generated chart/image descriptions
- PDF accessibility auto-tagging (coming Q2 2026)

## Usage

### In NixOS Configuration

```nix
{
  environment.systemPackages = [
    pkgs.fmf.opendataloader-pdf
  ];
}
```

### Command Line

```bash
# Convert PDF to Markdown
opendataloader-pdf input.pdf -f markdown

# Convert to JSON with bounding boxes
opendataloader-pdf input.pdf -f json

# Batch processing
opendataloader-pdf file1.pdf file2.pdf folder/

# See all options
opendataloader-pdf --help
```

### In Python Scripts

The package includes the Python module, so you can also use it programmatically:

```python
import opendataloader_pdf

opendataloader_pdf.convert(
    input_path=["file1.pdf", "file2.pdf"],
    output_dir="output/",
    format="markdown,json"
)
```

## Package Details

- **Version**: 2.0.0
- **License**: Apache 2.0
- **Upstream**: https://github.com/opendataloader-project/opendataloader-pdf
- **PyPI**: https://pypi.org/project/opendataloader-pdf/
- **Java Requirement**: JDK 17 (included automatically)

## Implementation

This package:
1. Fetches the Python wheel from PyPI (includes bundled JAR files)
2. Creates a Python environment with the package installed
3. Wraps it in a `writeShellApplication` for easy CLI use
4. Ensures JDK 17 is available at runtime via `JAVA_HOME`

The package follows the repository's pattern for executable applications while providing full Python module access.

## Testing

```bash
# Build the package
nix build .#opendataloader-pdf

# Test the executable
./result/bin/opendataloader-pdf --help

# Run directly from flake
nix run .#opendataloader-pdf -- --help
```

## Notes

- The PyPI wheel includes all necessary JAR files
- Java 11+ is required (package uses JDK 17)
- For hybrid mode features (OCR, AI), additional dependencies may be needed
- See upstream documentation for advanced features
