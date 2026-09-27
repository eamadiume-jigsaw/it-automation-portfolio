import json
import os
import uuid
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})

    device = body.get("device")
    severity = body.get("severity")
    message = body.get("message")

    if not device or not severity or not message:
        return _response(400, {"error": "device, severity, and message are required"})

    if severity not in ("info", "warning", "critical"):
        return _response(400, {"error": "severity must be one of: info, warning, critical"})

    incident = {
        "incident_id": str(uuid.uuid4()),
        "device": device,
        "severity": severity,
        "message": message,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    table.put_item(Item=incident)

    return _response(201, incident)


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }