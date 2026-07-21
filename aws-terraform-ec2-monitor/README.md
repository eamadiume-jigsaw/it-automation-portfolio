# AWS EC2 & S3 Provisioning (Terraform) & Monitoring (boto3)

A multi-part AWS project: EC2 web infrastructure and an S3 bucket provisioned declaratively with Terraform, and a Python/boto3 script that reports live EC2 instance state, CloudWatch CPU metrics, and S3 bucket status across regions.

## Why

Built to demonstrate the same declarative-infrastructure mindset from the DSC and Ansible projects, applied to a public cloud platform. UK infrastructure and cloud job postings consistently ask for Terraform and AWS alongside on-prem tooling, so this project deliberately mirrors that existing skillset rather than treating cloud as a separate discipline.

## Design: no hardcoded AMI, no long-lived credentials in code, no public buckets by default

The Terraform config looks up the current Amazon Linux 2023 AMI dynamically via a data source at apply time, rather than hardcoding an AMI ID that goes stale as AWS rotates images. AWS credentials are never referenced in any `.tf` or `.py` file — both tools pick them up from the AWS CLI's local credential store (`aws configure`), configured once outside the repo. The S3 bucket explicitly blocks all public access at creation time via `aws_s3_bucket_public_access_block`, rather than relying on the account-level default — a bucket without this explicitly set is a common real-world security finding.

## What it does

**Terraform (`main.tf`)**
- Looks up the latest Amazon Linux 2023 AMI for the target region
- Creates a security group: SSH restricted to a single IP, HTTP open publicly
- Provisions a `t3.micro` EC2 instance, free-tier eligible
- Installs and starts nginx automatically via `user_data` on first boot — no manual SSH configuration required
- Provisions an S3 bucket with a randomized name suffix (S3 bucket names must be globally unique), versioning enabled, and all public access explicitly blocked
- Outputs the instance's public IP and the bucket name on apply

**Monitor (`ec2_monitor.py`)**
- Connects to AWS via boto3 using local CLI credentials
- Lists EC2 instances and state across multiple configured regions
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

Free-tier-eligible instance types vary by account and region — `t2.micro` was not eligible in this account's `eu-west-2`, while `t3.micro` was. The config assumes x86_64; Graviton (ARM, `t4g.*`) instance types would need a matching ARM AMI filter, not currently handled. The S3 bucket name in `BUCKETS` is currently hardcoded rather than pulled dynamically from Terraform state — a natural next step would be wiring the monitor script to read `terraform output` directly.