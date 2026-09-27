import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    incident_id = event.get("pathParameters", {}).get("id")

    if not incident_id:
        return _response(400, {"error": "Missing incident id in path"})

    response = table.get_item(Key={"incident_id": incident_id})
    item = response.get("Item")

    if not item:
        return _response(404, {"error": f"Incident {incident_id} not found"})

    return _response(200, item)


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }