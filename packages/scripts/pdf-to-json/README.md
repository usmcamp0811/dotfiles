# PDF to JSON

A script to extract form fields from a fillable PDF file and output the data in JSON format. This tool was created to simplify the process of analyzing PDF forms by converting their fields into a machine-readable format.

## Purpose

Working with fillable PDFs can be challenging, especially when you need to extract their form data for use in other applications. This script helps:

1. Extract all form fields from a fillable PDF.
2. Output the extracted data in a structured and valid JSON format.
3. Simplify the process of integrating PDF form data into other workflows.

## Features

- **Form field extraction**: Extracts field names and their values from fillable PDFs.
- **JSON output**: Converts the extracted data into a valid and easy-to-use JSON format.
- **Command-line arguments**: Specify the PDF file path for seamless integration into scripts and automation.

## Usage

### Command-line Arguments

```bash
nix run gitlab:usmcamp0811/dotfiles#pdf-to-json <pdf_path>
```

- `<pdf_path>`: Path to the fillable PDF file.

### Examples

#### Basic PDF Form Extraction

Extract form fields from a PDF and output the data in JSON format:

```bash
nix run gitlab:usmcamp0811/dotfiles#pdf-to-json -- my_form.pdf
```

The output will display the form fields in JSON format:

```json
{
  "Field1": "Value1",
  "Field2": "Value2",
  "Field3": ""
}
```

## Output Format

The output is a JSON object where:

- Each key represents a form field name.
- Each value represents the corresponding form field value (or an empty string if no value is set).

### Example Output

```json
{
  "name": "John Doe",
  "email": "john.doe@example.com",
  "comments": "Thank you!"
}
```

## Why Use This?

This tool was developed to make working with fillable PDFs easier. Manual extraction of form data can be time-consuming and error-prone. By automating this process and outputting the data in JSON format, this script provides:

- A reliable way to integrate PDF form data into other applications.
- An efficient method for analyzing form submissions.
- Simplified workflows for handling interactive PDFs.

Whether you're working with digital forms, automating workflows, or integrating PDF data into larger systems, **PDF to JSON** makes the process faster and more reliable.
