import boto3
import json
import os

# Initialize AWS clients
s3_client = boto3.client("s3")
textract_client = boto3.client("textract")


def lambda_handler(event, context):
    try:
        # Extract bucket and object key from the event
        source_bucket = event["Records"][0]["s3"]["bucket"]["name"]
        source_key = event["Records"][0]["s3"]["object"]["key"]

        # Output bucket and key
        output_bucket = os.environ["OUTPUT_BUCKET"]
        output_key = f"ocr-results/{source_key.rsplit('.', 1)[0]}.json"

        # Start Textract job
        response = textract_client.start_document_text_detection(
            DocumentLocation={"S3Object": {"Bucket": source_bucket, "Name": source_key}}
        )

        job_id = response["JobId"]
        print(f"Started Textract job with ID: {job_id}")

        # Wait for the Textract job to complete
        status = "IN_PROGRESS"
        while status == "IN_PROGRESS":
            response = textract_client.get_document_text_detection(JobId=job_id)
            status = response["JobStatus"]
            if status in ["SUCCEEDED", "FAILED"]:
                break

        if status == "FAILED":
            print(f"Textract job failed: {response}")
            return {"statusCode": 500, "body": json.dumps("Textract job failed.")}

        # Extract the OCR results
        pages = []
        while "NextToken" in response:
            pages.extend(response["Blocks"])
            response = textract_client.get_document_text_detection(
                JobId=job_id, NextToken=response["NextToken"]
            )
        pages.extend(response["Blocks"])

        # Save the OCR results to the output S3 bucket
        ocr_results = {"JobId": job_id, "OCRResults": pages}

        s3_client.put_object(
            Bucket=output_bucket, Key=output_key, Body=json.dumps(ocr_results, indent=4)
        )

        print(f"OCR results saved to s3://{output_bucket}/{output_key}")

        return {
            "statusCode": 200,
            "body": json.dumps(
                f"OCR results saved to s3://{output_bucket}/{output_key}"
            ),
        }

    except Exception as e:
        print(f"Error processing file: {e}")
        return {"statusCode": 500, "body": json.dumps(f"Error: {str(e)}")}
