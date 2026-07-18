\# AWS EC2 Provisioning (Terraform) \& Monitoring (boto3)



A two-part AWS project: EC2 web infrastructure provisioned declaratively with

Terraform, and a Python/boto3 script that reports live instance state and

CloudWatch CPU metrics across regions.



\## Why



Built to demonstrate the same declarative-infrastructure mindset from the DSC

and Ansible projects, applied to a public cloud platform. UK infrastructure

and cloud job postings consistently ask for Terraform and AWS alongside

on-prem tooling, so this project deliberately mirrors that existing skillset

rather than treating cloud as a separate discipline.



\## Design: no hardcoded AMI, no long-lived credentials in code



The Terraform config looks up the current Amazon Linux 2023 AMI dynamically

via a data source at apply time, rather than hardcoding an AMI ID that goes

stale as AWS rotates images. AWS credentials are never referenced in any

`.tf` or `.py` file — both tools pick them up from the AWS CLI's local

credential store (`aws configure`), configured once outside the repo.



\## What it does



\*\*Terraform (`main.tf`)\*\*

\- Looks up the latest Amazon Linux 2023 AMI for the target region

\- Creates a security group: SSH restricted to a single IP, HTTP open publicly

\- Provisions a `t3.micro` EC2 instance, free-tier eligible

\- Installs and starts nginx automatically via `user\_data` on first boot —

&#x20; no manual SSH configuration required

\- Outputs the instance's public IP on apply



\*\*Monitor (`ec2\_monitor.py`)\*\*

\- Connects to AWS via boto3 using local CLI credentials

\- Lists EC2 instances and state across multiple configured regions

\- Pulls average CPU utilization from CloudWatch for any running instance

\- Prints a readable snapshot report to the terminal



\## Setup



\*\*Terraform\*\*

1\. Install Terraform and the AWS CLI; run `aws configure` with an IAM user's

&#x20;  access key (not root)

2\. Create an EC2 key pair in your target region:

&#x20;  `aws ec2 create-key-pair --key-name <name> --region <region> --query "KeyMaterial" --output text > key.pem`

3\. Update `key\_name` and the SSH `cidr\_blocks` value in `main.tf` to match

&#x20;  your key pair name and public IP

4\. `terraform init`, `terraform plan`, `terraform apply`

5\. `terraform destroy` to tear down when done



\*\*Monitor\*\*

1\. `pip install boto3`

2\. Update the `REGIONS` list in `ec2\_monitor.py` to match your account

3\. `python ec2\_monitor.py`



\## Known limitation



Free-tier-eligible instance types vary by account and region — `t2.micro`

was not eligible in this account's `eu-west-2`, while `t3.micro` was.

The config assumes x86\_64; Graviton (ARM, `t4g.\*`) instance types would

need a matching ARM AMI filter, not currently handled.

