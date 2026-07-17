# RDS Broker Health Check

Monitors Remote Desktop Services broker health independently of Windows Server Manager's console, which can report a false "no deployment exists" error on legacy TS Session Broker farm configurations even when the deployment is fully functional.

Full write-up / case study: see the [root README](../README.md#rds-broker-health-check--alerting).

## What it does

- Checks the `tssdis` (RD Connection Broker) and WID service status
- Parses the Session Broker operational event log for real connection activity (successful logons vs. timeouts) over a configurable lookback window
- Logs results to CSV for historical tracking
- Optionally sends an email alert on Warning/Critical status via Microsoft Graph, using certificate-based app-only authentication

## Usage

Basic health check:
```powershell
.\RDSBrokerHealthCheck.ps1
```

Custom lookback window and CSV path:
```powershell
.\RDSBrokerHealthCheck.ps1 -LookbackHours 12 -CsvLogPath "D:\Logs\rds-health.csv"
```

With email alerting (Microsoft Graph, cert-based app-only auth):
```powershell
.\RDSBrokerHealthCheck.ps1 -SendAlertOnFailure `
    -TenantId "<tenant-id>" `
    -ClientId "<app-client-id>" `
    -CertificateThumbprint "<cert-thumbprint>" `
    -SenderUPN "alerts-mailbox@yourdomain.com" `
    -AlertRecipients "you@yourdomain.com"
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Healthy |
| 1 | Warning — services running, but elevated connection failure/timeout rate |
| 2 | Critical — broker or WID service not running |

## Requirements

- PowerShell 5.1+, run elevated
- Run on (or with access to the event logs of) the RD Connection Broker server
- For alerting: an Entra ID app registration with `Mail.Send` application permission (admin consent granted), a certificate for authentication, and — recommended — an Exchange Online **Application Access Policy** scoping the app to a single sender mailbox rather than tenant-wide send rights

## Scheduling

Intended to run on a schedule (e.g. hourly) via Windows Task Scheduler, running as `SYSTEM`. See the root README for the full setup walkthrough, including the security-scoping steps for the alerting mailbox.
