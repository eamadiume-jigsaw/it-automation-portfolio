# IT Infrastructure Automation Portfolio

Author: Enyioma Amadiume
IT Infrastructure Specialist | M365, Entra ID, Intune, Hyper-V, Fortinet

This repo contains automation projects built to solve real operational problems in a hybrid aviation IT environment (corporate office + hangar infrastructure). Each project was built end-to-end: authentication design, error handling, and unattended scheduled execution — not just one-off scripts.

## Projects

### 1. [M365 Governance & Reporting Automation Suite](./m365-automation-suite)
Three PowerShell/Microsoft Graph scripts that automate recurring identity, device, and license governance checks — running unattended via certificate-based app-only authentication and Windows Task Scheduler.

### 2. [DSC Server Security Baseline](./dsc-server-security-baseline)
A PowerShell Desired State Configuration (DSC) baseline that remotely hardens a Windows Server target: removing legacy insecure features, enforcing firewall/registry security settings, and provisioning a governed local admin account — with certificate-encrypted credential handling.

### 3. [Ansible Server Security Baseline](./ansible-server-baseline)
An Ansible role that applies the same security hardening goals as the DSC baseline — legacy feature removal, firewall enforcement, registry hardening, service assurance — using Ansible Vault for encrypted credential storage. Built to demonstrate the same outcome through a second, platform-agnostic configuration management tool.

### 4. [Network Device Monitor & Auto-Remediation](./network-monitor)
A Python monitoring tool that pings network devices (routers, switches, firewalls, servers) on a schedule, logs uptime history to SQLite, sends Microsoft Teams alerts on sustained failure, and attempts gated auto-remediation — restarting a Windows service via WinRM — but only on devices explicitly flagged as safe to touch. Production network gear stays monitor-and-alert-only by design, so a bug in the remediation logic can never reach it.

### 5. [AWS EC2 Provisioning (Terraform) & Monitoring (boto3)](./aws-terraform-ec2-monitor)
A two-part AWS project: EC2 web infrastructure provisioned declaratively with Terraform — including a dynamic AMI lookup instead of a hardcoded, staleness-prone image ID — alongside a Python/boto3 script that reports live instance state and CloudWatch CPU metrics across regions. Built to extend the same declarative-infrastructure mindset from the DSC and Ansible projects onto a public cloud platform.

### 6. [RDS Broker Health Check](./rds-broker-health-check)
A PowerShell health-check tool that monitors Remote Desktop Services broker health independently of Windows Server Manager's console — which can report a false "no deployment exists" error on legacy TS Session Broker farm configurations even when the deployment is fully functional. Checks the RD Connection Broker and WID service status, parses the Session Broker event log for real connection activity (successful logons vs. timeouts) over a configurable lookback window, logs results to CSV for historical tracking, and optionally sends email alerts via Microsoft Graph using certificate-based app-only authentication — scoped to a single sender mailbox via an Exchange Online Application Access Policy rather than tenant-wide send rights. Runs on a schedule via Windows Task Scheduler.

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
- AWS: EC2, IAM (least-privilege user setup, MFA), CloudWatch metrics, boto3/AWS SDK for Python
- Windows Remote Desktop Services (RD Connection Broker) health monitoring: service status checks, Windows Event Log parsing, CSV-based historical logging, Graph-based email alerting scoped via Exchange Online Application Access Policy
- Environment-variable-based credential handling (no hardcoded secrets)
- Deliberate blast-radius/safety design for automation touching production systems
- Systematic troubleshooting of real infrastructure issues (RBAC propagation delays, WinRM/firewall configuration, module scope conflicts, UAC remote token restrictions, VPN subnet routing gaps, free-tier instance type eligibility across AWS regions)