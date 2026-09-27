import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    response = table.scan(Limit=50)
    items = response.get("Items", [])
    items.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

    return _response(200, {"count": len(items), "incidents": items})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }