"""
Log Ingestion API
------------------
Accepts log/event payloads via POST, validates them, and pushes them
onto an SQS queue for the worker service to process.

Locally (docker-compose) this talks to ElasticMQ, a lightweight
SQS-compatible server, via SQS_ENDPOINT_URL. In AWS it talks to real
SQS by leaving SQS_ENDPOINT_URL unset. Same code path either way --
that's the point: no special-cased "local mode" branching.
"""
import json
import logging
import os
import uuid
from datetime import datetime, timezone

import boto3
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ingestion-api")

app = FastAPI(title="Log Ingestion API", version="0.1.0")

# --- Config -----------------------------------------------------------
QUEUE_URL = os.environ["QUEUE_URL"]  # required, e.g. http://elasticmq:9324/queue/events (local)
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
SQS_ENDPOINT_URL = os.environ.get("SQS_ENDPOINT_URL")  # unset in real AWS

if SQS_ENDPOINT_URL:
    # Local ElasticMQ: it ignores credentials, but boto3 requires *something*.
    # Passing explicit creds here is safe only because this branch never runs in AWS.
    sqs_client = boto3.client(
        "sqs",
        region_name=AWS_REGION,
        endpoint_url=SQS_ENDPOINT_URL,
        aws_access_key_id="local",
        aws_secret_access_key="local",
    )
else:
    # Real AWS: do NOT pass explicit credentials. Leaving them unset lets boto3
    # use its default credential chain, which picks up the ECS task role.
    # Passing any explicit value here (even a placeholder) skips that chain
    # and causes SQS calls to fail with an auth error.
    sqs_client = boto3.client("sqs", region_name=AWS_REGION)


# --- Schema -------------------------------------------------------------
class LogEvent(BaseModel):
    source: str = Field(..., description="Where the event came from, e.g. 'app-server-1'")
    level: str = Field(..., description="info | warning | error | critical")
    message: str
    metadata: dict = Field(default_factory=dict)


# --- Routes ---------------------------------------------------------------
@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/events")
def ingest_event(event: LogEvent):
    if event.level not in {"info", "warning", "error", "critical"}:
        raise HTTPException(status_code=400, detail="invalid level")

    payload = {
        "event_id": str(uuid.uuid4()),
        "received_at": datetime.now(timezone.utc).isoformat(),
        **event.model_dump(),
    }

    try:
        sqs_client.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(payload))
        logger.info("Enqueued event %s", payload["event_id"])
    except Exception:
        logger.exception("Failed to enqueue event")
        raise HTTPException(status_code=502, detail="failed to enqueue event")

    return {"status": "accepted", "event_id": payload["event_id"]}
