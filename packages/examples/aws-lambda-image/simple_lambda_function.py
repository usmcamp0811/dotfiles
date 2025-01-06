import requests
import json


def handler(event, context):
    response = requests.get("https://wttr.in?format=j1")
    data = response.json()
    return {"statusCode": 200, "body": json.dumps(data)}
