# AWS EC2, VPC & S3 Provisioning (Terraform) & Monitoring (boto3)

A multi-part AWS project: a custom VPC with a public subnet hosting an EC2 web server, an S3 bucket, all provisioned declaratively with Terraform, and a Python/boto3 script that reports live EC2 instance state, CloudWatch CPU metrics, and S3 bucket status across regions.

## Why

Built to demonstrate the same declarative-infrastructure mindset from the DSC and Ansible projects, applied to a public cloud platform. UK infrastructure and cloud job postings consistently ask for Terraform, AWS networking, and cloud storage alongside on-prem tooling, so this project deliberately mirrors that existing skillset rather than treating cloud as a separate discipline.

## Design: no hardcoded AMI, no long-lived credentials in code, no public buckets by default, no default VPC

The Terraform config looks up the current Amazon Linux 2023 AMI dynamically via a data source at apply time, rather than hardcoding an AMI ID that goes stale as AWS rotates images. AWS credentials are never referenced in any `.tf` or `.py` file — both tools pick them up from the AWS CLI's local credential store (`aws configure`), configured once outside the repo. The S3 bucket explicitly blocks all public access at creation time via `aws_s3_bucket_public_access_block`, rather than relying on the account-level default. The EC2 instance runs inside a purpose-built VPC and public subnet rather than AWS's default VPC, with its own internet gateway and route table — a deliberate, minimal example of designing network boundaries rather than accepting whatever AWS provisions automatically.

## What it does

**Terraform (`main.tf`)**
- Creates a custom VPC (`10.0.0.0/16`) with a public subnet, an internet gateway, and a route table directing internet-bound traffic through the gateway
- Looks up the latest Amazon Linux 2023 AMI for the target region
- Creates a security group inside the custom VPC: SSH restricted to a single IP, HTTP open publicly
- Provisions a `t3.micro` EC2 instance inside the public subnet, free-tier eligible
- Installs and starts nginx automatically via `user_data` on first boot — no manual SSH configuration required
- Provisions an S3 bucket with a randomized name suffix (S3 bucket names must be globally unique), versioning enabled, and all public access explicitly blocked
- Outputs the instance's public IP, the VPC ID, and the bucket name on apply

**Monitor (`ec2_monitor.py`)**
- Connects to AWS via boto3 using local CLI credentials
- Lists EC2 instances and state across multiple configured regions, filtering out terminated/shutting-down instances so the report reflects only currently active resources
- Pulls average CPU utilization from CloudWatch for any running instance
- Reports object count and total size for each configured S3 bucket
- Re-verifies at monitoring time that each bucket's public access block is still fully enforced, flagging a warning if it isn't
- Prints a readable snapshot report to the terminal

## Setup

**Terraform**
1. Install Terraform and the AWS CLI; run `aws configure` with an IAM user's access key (not root)
2. Create an EC2 key pair in your target region:
   `aws ec2 create-key-pair --key-name <name> --region <region> --query "KeyMaterial" --output text > key.pem`
3. Update `key_name` and the SSH `cidr_blocks` value in `main.tf` to match your key pair name and public IP
4. `terraform init`, `terraform plan`, `terraform apply`
5. `terraform destroy` to tear down when done

**Monitor**
1. `pip install boto3`
2. Update the `REGIONS` list in `ec2_monitor.py` to match your account, and the `BUCKETS` list with the bucket name(s) output by `terraform apply`
3. `python ec2_monitor.py`

## Known limitation

Free-tier-eligible instance types vary by account and region — `t2.micro` was not eligible in this account's `eu-west-2`, while `t3.micro` was. The config assumes x86_64; Graviton (ARM, `t4g.*`) instance types would need a matching ARM AMI filter, not currently handled. The S3 bucket name in `BUCKETS` is currently hardcoded rather than pulled dynamically from Terraform state — a natural next step would be wiring the monitor script to read `terraform output` directly. The VPC currently has only a public subnet; a private subnet (no direct internet route, used for backend/database resources) is a logical next addition but not yet implemented. Moving the EC2 instance and security group into the new VPC required Terraform to destroy and recreate both, since neither resource type supports an in-place VPC change — expected behavior, confirmed via `terraform plan` before applying.