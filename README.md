# IT Infrastructure Automation Portfolio

Author: Enyioma Amadiume  
IT Infrastructure Specialist | M365, Entra ID, Intune, Hyper-V, Fortinet

This repo contains automation projects built to solve real operational problems in a
hybrid aviation IT environment (corporate office + hangar infrastructure). Each project
was built end-to-end: authentication design, error handling, and unattended scheduled
execution — not just one-off scripts.

## Projects

### 1. [M365 Governance & Reporting Automation Suite](./m365-automation-suite)
Three PowerShell/Microsoft Graph scripts that automate recurring identity, device, and
license governance checks — running unattended via certificate-based app-only
authentication and Windows Task Scheduler.

### 2. [DSC Server Security Baseline](./dsc-server-security-baseline)
A PowerShell Desired State Configuration (DSC) baseline that remotely hardens a Windows
Server target: removing legacy insecure features, enforcing firewall/registry security
settings, and provisioning a governed local admin account — with certificate-encrypted
credential handling.

### 3. [Ansible Server Security Baseline](./ansible-server-baseline)
An Ansible role that applies the same security hardening goals as the DSC baseline —
legacy feature removal, firewall enforcement, registry hardening, service assurance —
using Ansible Vault for encrypted credential storage. Built to demonstrate the same
outcome through a second, platform-agnostic configuration management tool.

## Skills demonstrated across these projects

- Microsoft Graph API scripting (PowerShell + Graph SDK)
- Certificate-based app-only authentication (Entra ID App Registrations)
- Least-privilege API permission scoping and admin consent workflows
- Unattended task scheduling (Windows Task Scheduler)
- PowerShell Desired State Configuration (DSC), including remote nodes
- DSC credential encryption via Document Encryption certificates
- Ansible role-based configuration management (WinRM-managed Windows targets)
- Ansible Vault credential encryption
- Systematic troubleshooting of real infrastructure issues (RBAC propagation delays,
  WinRM/firewall configuration, module scope conflicts, UAC remote token restrictions)
