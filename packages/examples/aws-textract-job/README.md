# AWS Lambda PDF OCR with Textract

Need to process PDFs with OCR using AWS Lambda? This example demonstrates how to create a Lambda function that extracts text from PDFs in an S3 bucket using Amazon Textract, with the results saved back to an S3 bucket. The function is packaged with Nix, ensuring reproducibility and streamlined builds.

## Overview

This example includes:

- A Lambda function to OCR PDFs from S3 and save the results back to S3.
- A Nix package `aws_textract_job` to build and deploy the Lambda function.
- Simple commands to test and deploy the function using Nix.
- Pass-through attributes for development and testing.

## Lambda Function Details

The `aws_textract_job` Lambda function:

- Reads PDF files from a source S3 bucket triggered by `s3:ObjectCreated` events.
- Uses Amazon Textract to perform OCR on the PDF.
- Saves the OCR results as a JSON file in a target S3 bucket.

## Pass-Through Attributes

The Lambda package includes additional pass-through attributes to streamline development and testing:

- **`appSource`**: The application source code directory, bundled into the Docker image.
- **`awsLambdaRie`**: A script to run the AWS Lambda Runtime Interface Emulator locally. Use it to test the Lambda function without deploying to AWS.

  Example usage:

  ```bash
  nix run .#aws_textract_job.awsLambdaRie -- -d /path/to/code -p 9001 -h 0.0.0.0 lambda_function.lambda_handler
  ```

- **`devServer`**: A development server with hot-reload capabilities, monitoring changes to your Lambda source code and restarting the emulator as needed.

  Example usage:

  ```bash
  nix run .#aws_textract_job.devServer -- -d /path/to/code -p 9001 -h 0.0.0.0 lambda_function.lambda_handler
  ```

These tools simplify the local development process and reduce the need for repeated deployment to AWS during testing.

## How to Use

1. **Build the Lambda Package**:

   Build the Lambda package using Nix:

   ```bash
   nix build .#aws_textract_job
   ```

   The output will be a zip file ready to upload to AWS Lambda.

2. **Upload the Package to AWS Lambda**:

   Use the AWS CLI to create or update your Lambda function:

   ```bash
   aws lambda create-function \
       --function-name aws_textract_job \
       --runtime python3.9 \
       --role <your-lambda-execution-role-arn> \
       --handler lambda_function.lambda_handler \
       --code S3Bucket=<your-bucket>,S3Key=<path-to-lambda-zip>
   ```

3. **Set Up S3 Event Trigger**:

   Configure your source S3 bucket to trigger the Lambda function on `s3:ObjectCreated:*` events.

4. **Test the Lambda Function**:

   Upload a PDF to the source S3 bucket and verify the OCR results in the target S3 bucket.
