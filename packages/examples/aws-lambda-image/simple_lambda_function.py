import os
import json
import requests
import boto3
from botocore.exceptions import BotoCoreError, ClientError
from tenacity import retry, stop_after_attempt, wait_exponential


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def fetch_weather_data(url):
    response = requests.get(url)
    response.raise_for_status()
    return response.json()


def handler(event, context):
    latitude = os.environ.get("LATITUDE", "35.6895")  # Default: Tokyo
    longitude = os.environ.get("LONGITUDE", "139.6917")  # Default: Tokyo
    bucket_name = os.environ.get("S3_BUCKET")
    s3_key = os.environ.get("S3_KEY", "weather_forecast.json")

    if not bucket_name:
        return {"statusCode": 400, "body": "S3_BUCKET environment variable is required"}

    url = f"https://api.open-meteo.com/v1/forecast?latitude={latitude}&longitude={longitude}&current_weather=true"

    try:
        data = fetch_weather_data(url)
        print(data)

        json_data = json.dumps(data, indent=2)

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
