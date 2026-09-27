# Cloud & Infrastructure Automation Portfolio

**Enyioma Amadiume**, Senior IT Infrastructure Specialist, moving into cloud and infrastructure engineering
AWS · Azure · Terraform · Python · PowerShell · GitHub Actions · M365 / Entra ID · [eamadiume.com](https://eamadiume.com)

Twelve end-to-end projects in two tracks:

- **Cloud engineering (AWS & Azure):** infrastructure defined in Terraform, least-privilege IAM, containers, serverless, and CI/CD with no stored credentials. Each one was built, tested against live infrastructure, documented, and torn down cleanly.
- **Infrastructure automation:** PowerShell, Python and Ansible tooling built for real operational problems in a hybrid aviation IT environment (corporate office and hangar), designed for unattended scheduled execution with certificate-based authentication.

Every project README documents the real problems hit along the way and how they were diagnosed, not just the finished result.

**Start here:** [Serverless Incident API](./serverless-incident-api) (per-function IAM and permissions boundaries, proven with the Policy Simulator) · [ECS Fargate Log Pipeline](./log-pipeline) (a credential-chain bug that only appeared in AWS) · [Terraform CI/CD with OIDC](./ci-cd-pipeline) (approval-gated applies, no stored keys) · [Secure Web App Case Study](./aws-secure-web-app-case-study) (private RDS, least-privilege deployer)

## Projects

### 1. [M365 Governance & Reporting Automation Suite](./m365-automation-suite)
Three PowerShell/Microsoft Graph scripts that automate recurring identity, device, and license governance checks — running unattended via certificate-based app-only authentication and Windows Task Scheduler.

### 2. [DSC Server Security Baseline](./dsc-server-security-baseline)
A PowerShell Desired State Configuration (DSC) baseline that remotely hardens a Windows Server target: removing legacy insecure features, enforcing firewall/registry security settings, and provisioning a governed local admin account — with certificate-encrypted credential handling.

### 3. [Ansible Server Security Baseline](./ansible-server-baseline)
An Ansible role that applies the same security hardening goals as the DSC baseline — legacy feature removal, firewall enforcement, registry hardening, service assurance — using Ansible Vault for encrypted credential storage. Built to demonstrate the same outcome through a second, platform-agnostic configuration management tool.

### 4. [Network Device Monitor & Auto-Remediation](./network-monitor)
A Python monitoring tool that pings network devices (routers, switches, firewalls, servers) on a schedule, logs uptime history to SQLite, sends Microsoft Teams alerts on sustained failure, and attempts gated auto-remediation — restarting a Windows service via WinRM — but only on devices explicitly flagged as safe to touch. Production network gear stays monitor-and-alert-only by design, so a bug in the remediation logic can never reach it.

### 5. [AWS EC2, VPC & S3 Provisioning (Terraform) & Monitoring (boto3)](./aws-terraform-ec2-monitor)
A multi-part AWS project: a custom VPC with a public subnet hosting an EC2 web server, an S3 bucket, all provisioned declaratively with Terraform, and a Python/boto3 script that reports live EC2 instance state, CloudWatch CPU metrics, and S3 bucket status across regions.

### 6. [RDS Broker Health Check](./rds-broker-health-check)
A PowerShell health-check tool that monitors Remote Desktop Services broker health independently of Windows Server Manager's console — which can report a false "no deployment exists" error on legacy TS Session Broker farm configurations even when the deployment is fully functional. Checks the RD Connection Broker and WID service status, parses the Session Broker event log for real connection activity (successful logons vs. timeouts) over a configurable lookback window, logs results to CSV for historical tracking, and optionally sends email alerts via Microsoft Graph using certificate-based app-only authentication — scoped to a single sender mailbox via an Exchange Online Application Access Policy rather than tenant-wide send rights. Runs on a schedule via Windows Task Scheduler.

### 7. [Secure Web App Architecture: Case Study](./aws-secure-web-app-case-study)
A complete AWS architecture built to solve a realistic business requirement: an internet-facing web app backed by a database that must never be directly reachable from the internet, deployed entirely by a least-privilege IAM identity with no standing admin access. Includes a custom VPC with public and private subnet separation across two Availability Zones, an EC2 web server, an RDS MySQL database whose isolation was proven with live connectivity tests (blocked from the internet, reachable only from the app server), and AWS Systems Manager Session Manager as a port-22-independent access method. The IAM policy was scoped iteratively against real `AccessDenied` errors from the actual build rather than guessed upfront, and IAM management is kept in a fully separate Terraform project from infrastructure management, mirroring a real separation-of-duties principle.

### 8. [Serverless Incident API](./serverless-incident-api)
A serverless REST API for logging infrastructure incidents (API Gateway HTTP API → three Python Lambdas → DynamoDB), deployed entirely with Terraform. The focus is least-privilege IAM: each function has its own role granting exactly one DynamoDB action (`PutItem`, `GetItem` or `Scan`) on one table, and every role is capped by a permissions boundary that the deploying user is required to attach, so even a widened inline policy can't exceed table + log access. Verified with the IAM Policy Simulator (`DeleteItem` and `iam:CreateUser` denied by the boundary) and live API tests covering validation (400), not-found (404) and unrouted methods. Includes route-scoped Lambda invoke permissions, stage throttling, on-demand billing and short log retention to keep a public, unauthenticated lab endpoint cheap and contained.

### 9. [Log Ingestion & Anomaly Detection Pipeline (ECS Fargate)](./log-pipeline)
An event-driven container pipeline: a FastAPI service accepts log events and queues them on SQS, and a Python worker polls the queue and flags error bursts (3+ error/critical events from one source within 60 seconds). The same code runs locally under Docker Compose against ElasticMQ and in AWS as two ECS Fargate services against real SQS. All 23 resources (VPC, per-service security groups, SQS, ECR, ECS, and an execution role separate from a task role scoped to one queue) are defined in Terraform. NAT Gateway and ALB were deliberately left out to avoid their standing costs. The deployment surfaced a real `InvalidClientTokenId` bug: placeholder credentials meant for local ElasticMQ bypassed boto3's default credential chain, so the ECS task role was never used. It was diagnosed from CloudWatch Logs rather than the surface 502, fixed, redeployed and verified, then the stack was destroyed cleanly.

### 10. [Terraform CI/CD Pipeline (GitHub Actions + OIDC)](./ci-cd-pipeline)
A GitHub Actions pipeline that validates, plans and applies Terraform against AWS with no stored credentials. It authenticates through OIDC federation to an IAM role whose trust policy is scoped to this repository. Validate, Plan and Apply are separate dependent jobs. The plan is posted to the pull request, apply waits for manual approval on a `production` environment, and branch protection blocks merges unless the checks pass. Documents three real failures and their fixes: a hardcoded local AWS profile that broke CI, a truncated workflow file that reported green while silently skipping steps, and a missing remote backend that orphaned infrastructure when the runner's local state disappeared. That last one was fixed with an S3 backend and native state locking, after the orphaned resources were removed by hand.

### 11. [Secure Multi-Environment Azure Infrastructure (Terraform)](./azure-secure-multi-env)
A single reusable Terraform module deployed to dev, staging and prod through thin per-environment configs and `.tfvars` files. Each environment has its own isolated state file in Azure Blob Storage, a deliberate choice over workspaces so a dev change can't be applied to prod. It builds a VNet with public/private subnet separation, two least-privilege NSGs with explicit deny-all rules, a VM in the private subnet with no public IP, and a storage account with public network access disabled. Includes a documented bootstrap for the remote-state backend and fixes for Azure Resource Manager propagation lag (`time_sleep` staging and `-parallelism=1`). A free-trial VM SKU restriction was properly diagnosed with quota and SKU checks rather than trial and error. Networking and storage are validated; VM validation is pending the subscription restriction lifting.

### 12. [Personal Portfolio Site: eamadiume.com](./eamadiume-personal-site)
A static site on a fully private S3 bucket behind CloudFront (Origin Access Control), with an ACM certificate and Route 53 DNS, costing under $1/month. Originally built in the console, it was **adopted into Terraform with a proven zero-change import**: 12 live resources, generated config cleaned into modules, and `prevent_destroy` on the critical pieces. It now deploys through a **GitHub Actions pipeline using OIDC**. The deploy role can only upload the one page and invalidate the one distribution, can only be assumed from `main`, and every run checks that the live site serves the exact committed file (SHA-256 match). Hardened with bucket versioning for rollback, IPv6 on both hostnames, and an account budget with actual and forecast alerts. The README documents the import pitfalls, the IAM managed-policy size limit, and catching a stale repo copy that would have silently rolled the site back. Live at [eamadiume.com](https://eamadiume.com).

## Skills demonstrated across these projects

- Microsoft Graph API scripting (PowerShell + Graph SDK)
- Certificate-based app-only authentication (Entra ID App Registrations)
- Least-privilege API permission scoping and admin consent workflows
- Unattended task scheduling (Windows Task Scheduler)
- PowerShell Desired State Configuration (DSC), including remote nodes
- DSC credential encryption via Document Encryption certificates
- Ansible role-based configuration management (WinRM-managed Windows targets)
- Ansible Vault credential encryption
- Python scripting: network monitoring, SQLite logging, webhook alerting, WinRM automation via pywinrm
- Infrastructure as Code with Terraform: dynamic resource lookups, security group design, automated provisioning via user_data
- AWS: EC2, VPC (public/private subnet design, NAT Gateway, route tables), RDS, S3, IAM (least-privilege policy design, iterative scoping against real errors, separation of duties), Systems Manager Session Manager, CloudWatch metrics, boto3/AWS SDK for Python
- Windows Remote Desktop Services (RD Connection Broker) health monitoring: service status checks, Windows Event Log parsing, CSV-based historical logging, Graph-based email alerting scoped via Exchange Online Application Access Policy
- Serverless on AWS: API Gateway (HTTP API), Lambda (Python), DynamoDB on-demand; per-function IAM roles, permissions boundaries, IAM Policy Simulator verification
- Containers: Docker, Docker Compose, Amazon ECR, ECS Fargate, SQS-based event-driven processing
- CI/CD for infrastructure: GitHub Actions, OIDC federation (no stored cloud credentials), staged validate/plan/apply jobs, manual approval gates, branch protection, S3 remote state with locking
- Azure with Terraform: reusable modules, per-environment isolated remote state, VNet/NSG network isolation, diagnosing ARM propagation lag and subscription SKU restrictions
- Static hosting and edge delivery: S3 + CloudFront with Origin Access Control, ACM, Route 53
- Environment-variable-based credential handling (no hardcoded secrets)
- Deliberate blast-radius/safety design for automation touching production systems
- Systematic troubleshooting of real infrastructure issues (RBAC propagation delays, WinRM/firewall configuration, module scope conflicts, UAC remote token restrictions, VPN subnet routing gaps, free-tier instance type eligibility across AWS regions, corporate endpoint security blocking outbound SSH, IAM service-linked role bootstrapping)