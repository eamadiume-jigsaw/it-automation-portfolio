# Log Pipeline — ECS Fargate Deployment

## What this is
A small ingest → queue → process pipeline:
- **API** (FastAPI) accepts log events over HTTP, pushes them to SQS
- **Worker** (Python) polls SQS, detects error-burst anomalies, writes to a local SQLite file
- Runs locally via Docker Compose against ElasticMQ (a fake local SQS), or on
  AWS via ECS Fargate against real SQS — same application code either way.

## Prerequisites
- AWS CLI configured (`aws sts get-caller-identity` should return your account)
- Terraform >= 1.5 installed (`terraform -version`)
- Docker installed and running

## 1. Provision the infrastructure

```powershell
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

Review the plan before typing `yes` at the apply prompt — this is the habit
worth building now: know what's about to be created before you create it.

When it finishes, note the outputs — you'll need the ECR repository URLs
and the cluster/service names.

## 2. Build and push the images to ECR

From the project root (one level up from `terraform/`):

```powershell
# Log in to ECR (replace <account-id> with your AWS account ID, shown by aws sts get-caller-identity)
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-2.amazonaws.com

# Build and tag
docker build -t log-pipeline-api ./api
docker tag log-pipeline-api:latest <account-id>.dkr.ecr.eu-west-2.amazonaws.com/log-pipeline-api:latest

docker build -t log-pipeline-worker ./worker
docker tag log-pipeline-worker:latest <account-id>.dkr.ecr.eu-west-2.amazonaws.com/log-pipeline-worker:latest

# Push
docker push <account-id>.dkr.ecr.eu-west-2.amazonaws.com/log-pipeline-api:latest
docker push <account-id>.dkr.ecr.eu-west-2.amazonaws.com/log-pipeline-worker:latest
```

Tip: the exact repository URLs are in your `terraform apply` output
(`ecr_api_repository_url`, `ecr_worker_repository_url`) — copy them from there
instead of retyping.

## 3. Deploy the images

The ECS services were created pointing at `:latest`, but they started before
any image existed, so force a fresh deployment now that images are pushed:

```powershell
aws ecs update-service --cluster log-pipeline-cluster --service log-pipeline-api --force-new-deployment
aws ecs update-service --cluster log-pipeline-cluster --service log-pipeline-worker --force-new-deployment
```

## 4. Find the API's public IP and test it

Fargate tasks don't have a fixed IP by default (no load balancer in this
setup, to keep cost near zero), so you look it up after each deployment:

```powershell
# Get the running task's ARN
aws ecs list-tasks --cluster log-pipeline-cluster --service-name log-pipeline-api

# Describe it to get the ENI (network interface) ID
aws ecs describe-tasks --cluster log-pipeline-cluster --tasks <task-arn> --query "tasks[0].attachments[0].details"

# Use the eni-xxxx value from above to get the public IP
aws ec2 describe-network-interfaces --network-interface-ids <eni-id> --query "NetworkInterfaces[0].Association.PublicIp" --output text
```

Then test it (from PowerShell):

```powershell
Invoke-RestMethod -Uri http://<public-ip>:8000/events -Method Post -ContentType "application/json" -Body '{"source":"app-server-1","level":"error","message":"disk usage 92%"}'
```

Send it 3+ times quickly, then check the worker's logs (next step) for the
ANOMALY warning.

## 5. Watch the logs

CloudWatch Logs has both services under `/ecs/log-pipeline-api` and
`/ecs/log-pipeline-worker`. Easiest via console (CloudWatch → Log groups),
or tail from CLI:

```powershell
aws logs tail /ecs/log-pipeline-worker --follow
```

## 6. Break something on purpose (Week 2 exercise)

Once the happy path works, this is where you actually practice
incident response instead of just deployment:
- Push a broken image (e.g. typo in a package name) and watch the service
  fail to stabilize — practice reading the ECS "stopped reason" for the task.
- Temporarily revoke the task role's SQS permission in IAM and watch the
  API's `502` responses / CloudWatch error logs — practice diagnosing an
  IAM issue from application-level symptoms.
- Note what you did and how you diagnosed it — this becomes the incident
  narrative for your portfolio README, which is more compelling to
  reviewers than a clean deploy story.

## 7. Tear down

**Don't skip this** — leaving Fargate tasks running is the main way this
stops being free:

```powershell
cd terraform
terraform destroy
```

Confirm the plan shows everything being deleted (cluster, services, IAM
roles, VPC, ECR repos, SQS queue) before typing `yes`.
