# M365 Governance & Reporting Automation Suite

Three scheduled PowerShell scripts that automate recurring Microsoft 365 governance
checks using the Microsoft Graph API, authenticating as a dedicated app registration
rather than a signed-in user — so they run unattended, on schedule, with no human
interaction required.

## Problem

Identity, device compliance, and license governance checks were being done manually and
inconsistently — a time cost, and a gap that matters for security audits and license
cost control.

## What each script does

| Script | Purpose | Schedule |
|---|---|---|
| `Get-InactiveUsers.ps1` | Flags Entra ID accounts with no sign-in activity in 60+ days | Weekly |
| `Get-IntuneComplianceReport.ps1` | Flags Intune-managed devices that are non-compliant or haven't synced in 14+ days | Daily |
| `Get-LicenseUsageReport.ps1` | Maps every assigned M365 license to its user, flagging licenses on disabled accounts | Weekly |

Each script exports to CSV for review and integrates into a recurring audit/reporting
workflow.

## Architecture

```
Windows Task Scheduler (unattended trigger)
        │
        ▼
pwsh.exe -File script.ps1
        │
        ▼
Connect-MgGraph (certificate-based app-only auth)
        │
        ▼
Microsoft Graph API (Entra ID / Intune / Licensing)
        │
        ▼
CSV export → reports folder
```

## Authentication design

These scripts do **not** use interactive/delegated login. Instead:

1. A dedicated Entra ID App Registration was created, scoped to exactly the four
   Microsoft Graph **Application permissions** each script needs
   (`User.Read.All`, `AuditLog.Read.All`, `DeviceManagementManagedDevices.Read.All`,
   `Organization.Read.All`) — least privilege, admin-consented once.
2. Authentication uses a **self-signed certificate** (private key never leaves the host
   machine) rather than a client secret — avoiding a stored plaintext credential.
3. Windows Task Scheduler runs each script under "run whether user is logged on or not,"
   which is what makes true unattended, scheduled execution possible.

See `Connect-GraphAppOnly.ps1` for the reusable connection snippet used by all three
scripts.

## Real problem solved during build

Windows Task Scheduler tasks initially failed with a launch error because
`pwsh.exe` isn't resolvable by name in a non-interactive Task Scheduler context (no
inherited user PATH) — fixed by pointing the Action directly at the full binary path.

## Setup

1. Create an Entra ID App Registration, grant the four Graph Application permissions
   above, and admin-consent.
2. Generate a self-signed certificate, upload the public key to the App Registration.
3. Update the placeholder variables at the top of each script
   (`YOUR_APP_ID`, `YOUR_TENANT_ID`, `YOUR_CERT_THUMBPRINT`).
4. Schedule each script in Task Scheduler pointing at the full path to `pwsh.exe`.

> Note: scripts in this repo have all tenant-specific identifiers (App ID, Tenant ID,
> certificate thumbprint, organization domain) replaced with placeholders.
