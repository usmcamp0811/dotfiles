import requests
import json
import sys


# def handler(event, context):
#     response = requests.get("https://api.github.com")
#     data = response.json()
#     return {"statusCode": 200, "body": json.dumps(data)}


def handler(event, context):
    return f"""Hello from AWS Lambda using Python {sys.version}!"""
