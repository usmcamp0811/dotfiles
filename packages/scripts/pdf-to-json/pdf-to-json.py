import json
import sys
from PyPDF2 import PdfReader
import argparse


def extract_pdf_fields(pdf_path):
    """
    Extract form fields from a fillable PDF and return them as a dictionary.

    Args:
        pdf_path (str): Path to the PDF file.

    Returns:
        dict: A dictionary containing field names as keys and their values as values.
    """
    reader = PdfReader(pdf_path)
    fields = {}

    if reader.pages:  # Check if PDF has pages
        for page in reader.pages:
            if "/Annots" in page:
                for annotation in page["/Annots"]:
                    annot = annotation.get_object()
                    if "/T" in annot and "/V" in annot:
                        field_name = annot["/T"]  # Field name
                        field_value = annot.get("/V", "")  # Field value
                        fields[field_name] = field_value

    return fields


def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description="Extract form fields from a PDF.")
    parser.add_argument("pdf_path", help="Path to the PDF file")

    # Parse arguments
    args = parser.parse_args()

    # Extract form fields
    try:
        form_fields = extract_pdf_fields(args.pdf_path)
        # Print form fields as valid JSON
        print(json.dumps(form_fields, indent=4))
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
