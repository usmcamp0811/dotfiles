import os
import json
import requests
import boto3
from botocore.exceptions import BotoCoreError, ClientError


def handler(event, context):
    # Get latitude, longitude, bucket name, and file name from environment variables
    latitude = os.environ.get("LATITUDE", "35.6895")  # Default: Tokyo, Japan
    longitude = os.environ.get("LONGITUDE", "139.6917")  # Default: Tokyo, Japan
    bucket_name = os.environ.get("S3_BUCKET")
    s3_key = os.environ.get("S3_KEY", "weather_forecast.json")

    if not bucket_name:
        return {"statusCode": 400, "body": "S3_BUCKET environment variable is required"}

    # Build the Open-Meteo API URL
    url = f"https://api.open-meteo.com/v1/forecast?latitude={latitude}&longitude={longitude}&current_weather=true"

    try:
        # Fetch the weather data
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        print(data)

        # Convert the data to a JSON string
        json_data = json.dumps(data, indent=2)

        # Save the data to the S3 bucket
        s3_client = boto3.client("s3")
        s3_client.put_object(
            Bucket=bucket_name,
            Key=s3_key,
            Body=json_data,
            ContentType="application/json",
        )

        return {
            "statusCode": 200,
            "body": f"Weather forecast saved to S3 bucket {bucket_name} with key {s3_key}",
        }
    except (requests.RequestException, BotoCoreError, ClientError) as e:
        return {"statusCode": 500, "body": f"Error: {e}"}
