# Ansible Server Security Baseline

An Ansible role that remotely hardens a Windows Server target, using WinRM for
connectivity and Ansible Vault for encrypted credential storage. This mirrors the
DSC Server Security Baseline project in this portfolio, applying the same hardening
goals through a different configuration management tool.

## What the baseline enforces

- Removes legacy insecure Windows features (Telnet Client, SMB1)
- Disables AutoAdminLogon via registry (prevents plaintext credential storage)
- Blocks the legacy Telnet port via a Windows Firewall rule
- Ensures a required service stays running
- Creates a standard automation folder structure
- Logs every actual change to a timestamped file on the target, via an Ansible handler

## Structure

ansible-lab contains: inventory.ini (target host and connection config), site.yml
(top-level playbook), group_vars/windows/vault.yml (encrypted credentials via Ansible
Vault), and roles/server-baseline/ containing defaults/main.yml (configurable
variables), tasks/main.yml (the hardening tasks), and handlers/main.yml (the
change-logging handler).

## Credential security

The Windows admin password is never stored in plain text. It is encrypted using
Ansible Vault and referenced in the inventory via a Jinja2 variable
(vault_ansible_password), resolved automatically from group_vars/windows/vault.yml
at runtime. The encrypted vault file is safe to commit to version control, since it
is unreadable without the separate vault password, which is never stored in the repo.

## Usage

ansible-playbook -i inventory.ini site.yml --ask-vault-pass

## Why both DSC and Ansible

DSC and Ansible solve the same problem, declarative and idempotent configuration
management, with different underlying models. DSC is PowerShell-native and pairs
naturally with a pure Microsoft stack. Ansible is platform-agnostic (the same control
node here could just as easily manage Linux targets) and is the more common choice in
mixed environments and most job postings. Building both was a deliberate choice to
demonstrate range rather than depth in only one ecosystem.
