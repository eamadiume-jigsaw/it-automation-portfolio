# \# IT Infrastructure Automation Portfolio

# 

# Author: Enyioma Amadiume

# IT Infrastructure Specialist | M365, Entra ID, Intune, Hyper-V, Fortinet

# 

# This repo contains automation projects built to solve real operational problems in a

# hybrid aviation IT environment (corporate office + hangar infrastructure). Each project

# was built end-to-end: authentication design, error handling, and unattended scheduled

# execution — not just one-off scripts.

# 

# \## Projects

# 

# \### 1. \[M365 Governance \& Reporting Automation Suite](./m365-automation-suite)

# Three PowerShell/Microsoft Graph scripts that automate recurring identity, device, and

# license governance checks — running unattended via certificate-based app-only

# authentication and Windows Task Scheduler.

# 

# \### 2. \[DSC Server Security Baseline](./dsc-server-security-baseline)

# A PowerShell Desired State Configuration (DSC) baseline that remotely hardens a Windows

# Server target: removing legacy insecure features, enforcing firewall/registry security

# settings, and provisioning a governed local admin account — with certificate-encrypted

# credential handling.

# 

# \### 3. \[Ansible Server Security Baseline](./ansible-server-baseline)

# An Ansible role that applies the same security hardening goals as the DSC baseline —

# legacy feature removal, firewall enforcement, registry hardening, service assurance —

# using Ansible Vault for encrypted credential storage. Built to demonstrate the same

# outcome through a second, platform-agnostic configuration management tool.

# 

# \### 4. \[Network Device Monitor \& Auto-Remediation](./network-monitor)

# A Python monitoring tool that pings network devices (routers, switches, firewalls,

# servers) on a schedule, logs uptime history to SQLite, sends Microsoft Teams alerts on

# sustained failure, and attempts gated auto-remediation — restarting a Windows service

# via WinRM — but only on devices explicitly flagged as safe to touch. Production network

# gear stays monitor-and-alert-only by design, so a bug in the remediation logic can

# never reach it.

# 

# \### 5. \[AWS EC2 Provisioning (Terraform) \& Monitoring (boto3)](./aws-terraform-ec2-monitor)

# A two-part AWS project: EC2 web infrastructure provisioned declaratively with

# Terraform — including a dynamic AMI lookup instead of a hardcoded, staleness-prone

# image ID — alongside a Python/boto3 script that reports live instance state and

# CloudWatch CPU metrics across regions. Built to extend the same declarative-

# infrastructure mindset from the DSC and Ansible projects onto a public cloud platform.

# 

# \### 6. \[RDS Broker Health Check](./rds-broker-health-check)

# A health-check tool that verifies the Remote Desktop Services (RDS) broker server —

# the entry point remote workers connect through — is up and accepting connections,

# flagging problems before they lock out remote staff. Built in response to RDS broker

# issues being a high-impact, easy-to-miss failure mode: unlike a downed website or

# internal file share, a broken broker can silently cut off an entire remote workforce

# until someone happens to try connecting and fails.

# 

# \## Skills demonstrated across these projects

# 

# \- Microsoft Graph API scripting (PowerShell + Graph SDK)

# \- Certificate-based app-only authentication (Entra ID App Registrations)

# \- Least-privilege API permission scoping and admin consent workflows

# \- Unattended task scheduling (Windows Task Scheduler)

# \- PowerShell Desired State Configuration (DSC), including remote nodes

# \- DSC credential encryption via Document Encryption certificates

# \- Ansible role-based configuration management (WinRM-managed Windows targets)

# \- Ansible Vault credential encryption

# \- Python scripting: network monitoring, SQLite logging, webhook alerting, WinRM

# &#x20; automation via pywinrm

# \- Infrastructure as Code with Terraform: dynamic resource lookups, security group

# &#x20; design, automated provisioning via user\_data

# \- AWS: EC2, IAM (least-privilege user setup, MFA), CloudWatch metrics, boto3/AWS SDK

# &#x20; for Python

# \- Windows Remote Desktop Services (RDS) broker health monitoring

# \- Environment-variable-based credential handling (no hardcoded secrets)

# \- Deliberate blast-radius/safety design for automation touching production systems

# \- Systematic troubleshooting of real infrastructure issues (RBAC propagation delays,

# &#x20; WinRM/firewall configuration, module scope conflicts, UAC remote token restrictions,

# &#x20; VPN subnet routing gaps, free-tier instance type eligibility across AWS regions)

