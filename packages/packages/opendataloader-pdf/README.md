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

### Basic Usage

```nix
# In your NixOS configuration or flake
{
  environment.systemPackages = [
    pkgs.fmf.opendataloader-pdf
  ];
}
```

### With Hybrid Dependencies

For advanced features like OCR and AI-powered table extraction:

```nix
{
  environment.systemPackages = [
    pkgs.fmf.opendataloader-pdf.withHybrid
  ];
}
```

### Command Line

```bash
# Convert PDF to Markdown
opendataloader-pdf input.pdf --format markdown

# Convert to JSON with bounding boxes
opendataloader-pdf input.pdf --format json

# Batch processing
opendataloader-pdf file1.pdf file2.pdf folder/
```

### Python API

```python
import opendataloader_pdf

opendataloader_pdf.convert(
    input_path=["file1.pdf", "file2.pdf", "folder/"],
    output_dir="output/",
    format="markdown,json"
)
```

## Package Details

- **Version**: 2.0.0
- **License**: Apache 2.0
- **Upstream**: https://github.com/opendataloader-project/opendataloader-pdf

## Implementation Notes

This package:
1. Fetches the source from GitHub
2. Downloads the pre-built Java CLI from releases
3. Builds the Python wrapper using `buildPythonPackage`
4. Wraps the binaries to ensure Java (JDK 17) is available at runtime
5. Provides a `.withHybrid` variant that includes optional dependencies for advanced features

The package structure follows the upstream Python package layout, with the Java CLI JARs bundled during the build process.
