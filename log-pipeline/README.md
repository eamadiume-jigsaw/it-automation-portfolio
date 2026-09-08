# Log Ingestion & Anomaly Detection Pipeline (AWS ECS Fargate)

A small event-driven pipeline built to practice managing containerized
infrastructure end-to-end: provisioning, deployment, debugging a real
production-style incident, and teardown -- not just "hello world on Fargate."

## What it does

- A **FastAPI** service accepts log/event payloads over HTTP and pushes
  them onto a queue.
- A **Python worker** polls the queue, applies a sliding-window anomaly
  check (3+ error/critical events from the same source within 60 seconds),
  and writes results to storage.
- The same application code runs two ways with zero changes:
  - **Locally**, against ElasticMQ (an SQS-compatible server) via Docker
    Compose -- for fast iteration without touching AWS.
  - **In production**, against real **Amazon SQS**, running as two
    **ECS Fargate** services.

## Architecture

User -> API (Fargate, public IP) -> SQS queue -> Worker (Fargate) -> anomaly detection

Provisioned entirely with **Terraform**: a VPC with two public subnets,
security groups scoped per service, an SQS queue, ECR repositories for
both images, IAM roles (execution role + a task role scoped to exactly
one queue's SendMessage/ReceiveMessage/DeleteMessage), an ECS cluster,
and the two Fargate services.

No NAT Gateway, no load balancer -- Fargate tasks get a public IP
directly in a public subnet. Both are common cost traps for a learning
project (a NAT Gateway alone runs ~$32/month just to exist), and skipping
them here still leaves the exercise realistic: VPC design, security
groups, IAM scoping, and service networking are all still fully in play.

## The incident: a credential-chain bug that only showed up in AWS

This is the part of the project I would actually walk an interviewer through.

The app was built so the boto3 SQS client works identically whether it's
talking to local ElasticMQ or real AWS SQS -- controlled by whether an
SQS_ENDPOINT_URL environment variable is set. Locally, ElasticMQ ignores
credentials entirely, so the client was initialized with placeholder
values, defaulting to the literal string "local" when no explicit
credentials were supplied.

That worked perfectly in Docker Compose. It failed silently in exactly
the way you would want to catch in staging, not production: deployed to
ECS, every request to SQS came back with:

botocore.exceptions.ClientError: An error occurred (InvalidClientTokenId)
when calling the SendMessage operation: The security token included in
the request is invalid.

Root cause: passing any explicit aws_access_key_id / aws_secret_access_key
to a boto3 client -- even placeholder ones -- skips boto3's default
credential resolution chain entirely. In AWS, that chain is what
automatically picks up the ECS task role (the IAM permissions granted via
Terraform). By hardcoding a fallback value for local testing, the client
never got the chance to authenticate as the task role in production -- it
tried to authenticate as the string "local" instead, which AWS correctly
rejected.

Fix: branch on whether SQS_ENDPOINT_URL is set. Only pass explicit
placeholder credentials in the local/ElasticMQ branch. In the AWS branch,
construct the client with no credentials specified at all, letting boto3's
default chain resolve them from the environment -- which is exactly where
the ECS task role credentials live.

How I found it: read the actual traceback from CloudWatch Logs
(aws logs tail /ecs/log-pipeline-api) rather than guessing from symptoms.
The API layer only reported a generic 502; the real error was one layer
down, in the exception log.

This is a genuinely common ECS gotcha, not a contrived one -- "my code
works locally but gets auth errors in AWS" is one of the most frequent
real-world container debugging sessions, and now I have done the full
loop: reproduce, read the actual error (not just the surface symptom),
identify the credential-chain mechanism, fix it, redeploy, and confirm
via logs.

## What I practiced

- VPC and network design: public subnets across two AZs, route tables,
  internet gateway, security groups scoped per service (worker has no
  inbound rules at all -- it only needs egress)
- IAM least-privilege: a task role scoped to exactly the actions and
  exactly the one queue it needs, separate from the execution role
- Infrastructure as Code: the entire stack (23 resources) defined in
  Terraform, reviewed via plan before every apply, and cleanly removed
  via destroy with zero orphaned resources
- Container build/push/deploy workflow: Docker builds, ECR auth and
  push, force-new-deployment to roll out new images
- Debugging via observability, not guesswork: used CloudWatch Logs to
  find the actual exception rather than trial-and-error changes
- Cost-conscious architecture: deliberately avoided the two most common
  Fargate cost traps (NAT Gateway, ALB) for a short-lived learning
  exercise, while keeping the exercise realistic

## Stack

Python, FastAPI, boto3, Docker, Terraform, AWS (ECS Fargate, SQS, ECR,
VPC, IAM, CloudWatch)

## Repo layout

api/            FastAPI ingestion service
worker/         SQS-polling worker with anomaly detection
terraform/      Full infrastructure definition
docker-compose.yml   Local dev stack (API + worker + ElasticMQ)
