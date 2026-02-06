# STuff

```mermaid
graph TD
    A[PDF] -->|ingest| B[S3 Bucket]
    B -->|lambda| C[OCR]
    C --> D[AWS Glue Data Quality]
    D --> E[OMOP]

```
