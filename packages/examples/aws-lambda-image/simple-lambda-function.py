import requests
import json


def handler(event, context):
    response = requests.get("https://api.github.com")
    data = response.json()
    return {"statusCode": 200, "body": json.dumps(data)}
