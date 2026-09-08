"""
Log Processing Worker
----------------------
Polls the SQS queue for events, applies simple anomaly detection
(too many errors/criticals from one source in a short window), and
writes results to a local SQLite table (swap for RDS/DynamoDB later
if you want extra practice).

Same SQS-vs-ElasticMQ endpoint pattern as the API service.
"""
import json
import logging
import os
import sqlite3
import time
from collections import defaultdict, deque
from datetime import datetime, timezone

import boto3

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("worker")

QUEUE_URL = os.environ["QUEUE_URL"]
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
SQS_ENDPOINT_URL = os.environ.get("SQS_ENDPOINT_URL")
DB_PATH = os.environ.get("DB_PATH", "/data/events.db")
POLL_WAIT_SECONDS = int(os.environ.get("POLL_WAIT_SECONDS", "10"))
ANOMALY_THRESHOLD = int(os.environ.get("ANOMALY_THRESHOLD", "3"))
ANOMALY_WINDOW_SECONDS = int(os.environ.get("ANOMALY_WINDOW_SECONDS", "60"))

if SQS_ENDPOINT_URL:
    # Local ElasticMQ: ignores credentials, but boto3 requires *something*.
    sqs_client = boto3.client(
        "sqs",
        region_name=AWS_REGION,
        endpoint_url=SQS_ENDPOINT_URL,
        aws_access_key_id="local",
        aws_secret_access_key="local",
    )
else:
    # Real AWS: no explicit credentials -- let boto3's default chain pick up
    # the ECS task role. See api/main.py for the full explanation.
    sqs_client = boto3.client("sqs", region_name=AWS_REGION)

# source -> deque of recent error/critical timestamps, for a simple
# sliding-window anomaly check without needing an external store.
_recent_bad_events: dict[str, deque] = defaultdict(deque)


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS events (
            event_id TEXT PRIMARY KEY,
            source TEXT,
            level TEXT,
            message TEXT,
            received_at TEXT,
            processed_at TEXT,
            is_anomaly INTEGER
        )
        """
    )
    conn.commit()
    return conn


def is_anomaly(source: str, level: str) -> bool:
    if level not in ("error", "critical"):
        return False
    now = time.time()
    window = _recent_bad_events[source]
    window.append(now)
    cutoff = now - ANOMALY_WINDOW_SECONDS
    while window and window[0] < cutoff:
        window.popleft()
    return len(window) >= ANOMALY_THRESHOLD


def process_message(conn, body: dict):
    anomaly = is_anomaly(body["source"], body["level"])
    conn.execute(
        """
        INSERT OR REPLACE INTO events
        (event_id, source, level, message, received_at, processed_at, is_anomaly)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            body["event_id"],
            body["source"],
            body["level"],
            body["message"],
            body["received_at"],
            datetime.now(timezone.utc).isoformat(),
            int(anomaly),
        ),
    )
    conn.commit()
    if anomaly:
        logger.warning(
            "ANOMALY: source=%s hit %s+ error/critical events in %ss window",
            body["source"], ANOMALY_THRESHOLD, ANOMALY_WINDOW_SECONDS,
        )
    else:
        logger.info("Processed event %s from %s (%s)", body["event_id"], body["source"], body["level"])


def main():
    conn = init_db()
    logger.info("Worker started, polling %s", QUEUE_URL)
    while True:
        response = sqs_client.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=POLL_WAIT_SECONDS,
        )
        messages = response.get("Messages", [])
        for msg in messages:
            try:
                body = json.loads(msg["Body"])
                process_message(conn, body)
                sqs_client.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=msg["ReceiptHandle"])
            except Exception:
                logger.exception("Failed to process message, leaving on queue for retry")


if __name__ == "__main__":
    main()
