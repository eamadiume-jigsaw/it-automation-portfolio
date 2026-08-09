# Secure Web App Architecture: Case Study

A realistic AWS architecture built to answer a specific business problem, not just to demonstrate individual services in isolation. Provisioned entirely by a purpose-built, iteratively least-privileged IAM identity — no `AdministratorAccess` used for any part of the build after initial account bootstrap.

## The problem

A company needs an internet-facing web application backed by a database, with the following non-negotiable requirements:

- The web app must be reachable by users over the internet
- The database must never be directly reachable from the internet — only from the app server itself
- Whoever deploys this should not need root/admin AWS credentials for routine work
- Everything must be provisioned as code, not clicked together manually, so it can be torn down and rebuilt identically
- Basic monitoring is needed so the team knows if the app server or database goes down

## Architecture

## Architecture

```
                        Internet
                            |
                     Internet Gateway
                            |
        +--------------------------------------+
        |              Public Subnet            |
        |            - EC2 (web app)            |
        +--------------------------------------+
                            |
        +--------------------------------------+
        |     Private Subnets (2 AZs, required   |
        |             by RDS)                   |
        |           - RDS database              |
        +--------------------------------------+
```
          - **VPC** with one public subnet (web tier) and two private subnets across separate Availability Zones (required by RDS for its subnet group, even for a single non-Multi-AZ instance)
- **EC2** instance in the public subnet running nginx, reachable over HTTP
- **RDS MySQL** instance in the private subnets, `publicly_accessible = false`, with a security group that only accepts inbound MySQL traffic from the web server's security group — not from any IP range
- **S3 bucket** with public access explicitly blocked and versioning enabled
- All of the above provisioned by a **scoped IAM identity** with no IAM permissions of its own

## Design: least privilege, tested against real errors, not assumed

The deploying identity (`cloud-engineer-scoped`) was deliberately built with no broad `service:*` permissions. Rather than guessing the full permission set upfront, the policy was scoped to specific actions and then run against the real build — every `AccessDenied` error was resolved by adding exactly the missing permission, not by widening the policy speculatively. This surfaced a genuinely useful, non-obvious finding: **most AWS resource types require several read-only `Describe`/`Get` permissions beyond their obvious create/delete actions**, because Terraform (and the AWS provider generally) reads back resource state after changes to confirm what was actually applied. A policy that only grants `Create`/`Delete` actions will fail on the very next `plan` or `apply`.

**IAM management is deliberately separated from infrastructure management.** The scoped identity cannot read or modify its own IAM policy — creating and updating that policy requires admin credentials, managed in a completely separate Terraform project (`iam/`) with its own state. This mirrors a real separation-of-duties principle: the identity provisioning application infrastructure should not also be able to grant itself more access.

## Verified, not assumed

The core security property — "the database is unreachable from the internet but reachable from the app server" — was tested directly rather than inferred from the configuration:

- **From an external network**: `Test-NetConnection` against the RDS endpoint on port 3306 returned `TcpTestSucceeded : False` — connection blocked.
- **From the EC2 instance**: a TCP connection test against the same endpoint and port succeeded.

Since direct SSH to the instance was blocked by local network/endpoint policy during testing (an unrelated environmental restriction, not an AWS misconfiguration — see Known limitations), the in-instance test was run via **AWS Systems Manager Session Manager** instead of SSH: an IAM role and instance profile with the `AmazonSSMManagedInstanceCore` policy were attached to the instance, giving shell access through the AWS API with no inbound port 22 requirement at all. This turned out to be a more production-appropriate access pattern than SSH regardless — no open SSH port, no key management, all access logged through AWS's own audit trail.

## What's in this repo

- **`iam/main.tf`** — the least-privilege IAM policy, user, and access key, managed independently of infrastructure. Requires admin credentials to apply.
- **`infrastructure/main.tf`** — VPC, subnets, EC2, RDS, S3, and all networking, designed to be applied using the scoped `cloud-engineer-scoped` profile.
- **`ec2_monitor.py`** — Python/boto3 monitoring covering EC2 (state, CPU), S3 (object count, public-access status), and RDS (status, engine, public-accessibility) in one report.

## Setup

**IAM (one-time, admin credentials required)**
1. `cd iam`, `terraform init`, `terraform apply`
2. `terraform output cloud_engineer_secret_key` to retrieve the secret
3. `aws configure --profile cloud-engineer-scoped` with the generated access key/secret

**Infrastructure (scoped credentials)**
1. `cd infrastructure`
2. Update the SSH `cidr_blocks` value in `main.tf` to your current public IP
3. Create an EC2 key pair in your target region and update `key_name` to match
4. `terraform init`, `terraform plan`, `terraform apply`
5. `terraform destroy` when done — RDS deletion typically takes several minutes

**Monitoring**
1. `pip install boto3`
2. Update `REGIONS`, `BUCKETS`, and `DB_INSTANCES` in `ec2_monitor.py` to match deployed resources
3. `python ec2_monitor.py`

## Known limitations

- SSH access from a corporate-managed laptop was blocked by local endpoint security policy (likely FortiClient application control) even while disconnected from any VPN tunnel — general internet connectivity and HTTP to the instance both worked normally, isolating this as a local outbound-port restriction rather than an AWS-side issue. Verification proceeded via SSM Session Manager instead.
- A NAT Gateway and its supporting route table were built and verified to correctly route private-subnet traffic outbound, then deliberately removed before the RDS build, since RDS manages its own patching through AWS's internal network path and does not require outbound internet access via a customer-managed NAT Gateway. The NAT Gateway configuration is preserved (commented out) in `infrastructure/main.tf` for reference.
- The least-privilege IAM policy's `ec2:*` and `rds:*` action lists were built iteratively against actual `AccessDenied` errors during this specific build; a different architecture (e.g., adding Auto Scaling, Load Balancers, or Multi-AZ RDS) would likely surface additional missing permissions requiring further scoping.
- RDS requires AWS to create a one-time account-level service-linked role (`AWSServiceRoleForRDS`) on first use, which requires `iam:CreateServiceLinkedRole` — this was performed once using admin credentials rather than granting the scoped identity broader IAM access.