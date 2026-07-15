# Network Device Monitor & Auto-Remediation

A Python monitoring tool that pings network devices on a schedule, logs uptime
history to SQLite, sends Teams alerts on sustained failure, and optionally attempts
gated auto-remediation on devices explicitly flagged as safe to touch.

## Why

Built in response to a recurring pattern in infrastructure job postings: Python-based
monitoring and auto-remediation tooling, often alongside Windows/network device
management. This project monitors real production network infrastructure
(router, switch, firewall) alongside a test server, deliberately designed around a
safety principle most monitoring scripts skip: blast-radius control.

## Design: monitoring is universal, remediation is opt-in per device

Every device in devices.yml gets pinged, logged, and alerted on. Only devices
explicitly marked remediation_enabled true can ever have a remediation action
attempted against them. Production network gear (router, switch, firewall) stays
monitor-and-alert-only; only a designated test server has remediation enabled. This
means a bug in the remediation logic can never affect production infrastructure, since
the code path simply does not exist for devices not explicitly opted in.

## What it does

- Pings each configured device on a fixed interval
- Logs every check (up or down plus timestamp) to a local SQLite database
- After N consecutive failures (configurable threshold), sends a Microsoft Teams
  webhook alert
- For remediation-enabled devices only: attempts to restart a specified Windows
  service via WinRM, logs the before and after result

## Credential security

The remediation credential is read from an environment variable (VM_ADMIN_PASSWORD)
at runtime, never hardcoded or committed to the repository.

## Setup

1. python3 -m venv venv, then source venv/bin/activate
2. pip install pyyaml requests pywinrm
3. Edit devices.yml with real device IPs; set remediation_enabled true only on
   devices confidently safe to remediate automatically
4. Set your Teams webhook URL in monitor.py
5. export VM_ADMIN_PASSWORD equal to your password
6. python3 monitor.py

## Known limitation

Tested successfully against real ExecuJet network infrastructure from the office
network. Remote testing over VPN surfaced a separate, genuine finding: the VPN's
routed subnets do not currently reach the test server's subnet, and RDP (port 3389)
appears blocked for VPN-sourced traffic on at least one host despite ICMP succeeding.
This is a real infrastructure finding worth following up on separately, unrelated to
this tool's correctness.
