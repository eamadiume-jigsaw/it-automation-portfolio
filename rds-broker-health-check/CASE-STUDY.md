# RDS Broker Health Check & Alerting

A PowerShell monitoring solution that verifies Remote Desktop Services broker health independently of Windows Server Manager's console — built after a prolonged power outage required an emergency shutdown of all production servers, and Server Manager reported a false "no deployment" error on a fully functional RDS farm at restart.

---

## The Problem

A prolonged power outage forced an emergency shutdown of all production servers. On restart, the RDS host came back online with Server Manager displaying:

> *"A Remote Desktop Services deployment does not exist in the server pool."*

This is a high-anxiety message — it implies the entire RDS deployment is gone. The instinctive next step Server Manager suggests is running the **Add Roles and Features Wizard** to create a new deployment, which is exactly the wrong move if a working configuration already exists underneath: re-running that wizard against a live farm risks overwriting the existing broker/farm settings.

## Diagnosis

Rather than trusting the console message, I worked from first principles — checking the actual services and logs that RDS depends on, not the UI layer sitting on top of them.

1. **Checked the Remote Desktop Connection Broker service (`tssdis`)** — found `Running`.
2. **Checked the Windows Internal Database service (WID)**, which stores broker configuration on single-server deployments — also found `Running`.
3. Since both core services were healthy, the fault wasn't in the broker itself — it pointed to Server Manager's console view being out of sync with reality.
4. Pulled the **RD Connection Broker operational event log** directly:
   ```powershell
   Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-SessionBroker/Operational" -MaxEvents 30
   ```
   This showed live, successful connection activity — real users authenticating and being redirected to session hosts within the hour, with zero failures.

**Root cause identified:** this RDS environment was built as a legacy TS Session Broker farm (registry/GPO-configured) rather than through the modern Server Manager RDS Deployment wizard introduced in Windows Server 2012. Server Manager's overview page only recognizes deployments it created itself — it has no visibility into farms configured the older way, so it reports "no deployment" even when the farm is fully operational. **The alarming message was cosmetic. The service was never actually down.**

## The Bigger Problem This Exposed

A misleading console message like this is a genuine operational risk: an admin under pressure during an outage, without the context to know the message was a false positive, could easily run the wrong remediation and turn a non-issue into a real outage. That gap — no reliable, at-a-glance way to confirm real broker health — was worth solving properly rather than just noting for next time.

## The Solution

I built **`RDSBrokerHealthCheck.ps1`**, a monitoring script that checks the things that actually determine whether RDS is working, and is completely decoupled from Server Manager's console state:

- **Service health**: `tssdis` (broker) and WID service status
- **Real connection activity**: parses the Session Broker operational log for successful logons (event ID 818) vs. timeouts/failures (event ID 819) over a configurable lookback window, and calculates a live failure rate
- **Historical logging**: appends a timestamped row to a CSV on every run, building a queryable uptime/incident history over time
- **Exit codes** (`0` Healthy / `1` Warning / `2` Critical) so Task Scheduler and other monitoring tooling can act on results programmatically, not just read console output

### Automation

Deployed as an hourly **Windows Task Scheduler** job running under the `SYSTEM` account, so health data accumulates continuously without manual intervention:

```powershell
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
```

### Alerting — with Least-Privilege in Mind

A health check nobody looks at isn't much better than no health check, so I added automated email alerting for `Warning`/`Critical` status — but deliberately avoided the easy, over-permissioned route.

**Authentication:** Certificate-based app-only authentication against Microsoft Graph (`Mail.Send`), consistent with the auth pattern used across the rest of this portfolio's automation scripts — no client secrets stored anywhere. The script builds and signs its own JWT client assertion from a certificate in the local machine store and exchanges it directly with the Microsoft identity platform token endpoint.

**Scoping:** By default, an app registration granted `Mail.Send` *application* permission can send mail as **any mailbox in the tenant** — a significant blast radius for a single-purpose health-check script. To close that gap, I configured an **Exchange Online Application Access Policy**, restricting the app's Client ID to only ever send as one designated alerts mailbox:

```powershell
New-ApplicationAccessPolicy `
    -AppId "<app-client-id>" `
    -PolicyScopeGroupId "RDS-Alert-Senders" `
    -AccessRight RestrictAccess
```

Verified enforcement explicitly rather than assuming it worked:

```powershell
Test-ApplicationAccessPolicy -AppId "<app-client-id>" -Identity "alerts-mailbox@yourdomain.com"
# AccessCheckResult : Granted

Test-ApplicationAccessPolicy -AppId "<app-client-id>" -Identity "other-mailbox@yourdomain.com"
# AccessCheckResult : Denied
```

This confirms the app can act as the intended alerts mailbox and **nothing else** — even though the underlying Graph permission is nominally tenant-wide.

## Debugging Along the Way

Not everything worked first try, and I want to be transparent about that rather than presenting a sanitized version:

- **`Register-ScheduledTask` XML duration error** — `[TimeSpan]::MaxValue` produces a duration string outside the Task Scheduler XML schema's valid range. Fixed by using a large-but-finite duration (10 years) instead.
- **`New-ApplicationAccessPolicy` intermittent server-side error** — a transient Exchange Online backend issue; the policy had actually been created despite the error response, confirmed via a retry that correctly reported "duplicate policy found."
- **JWT signing failure (`Invalid algorithm specified`)** — certificates generated via `New-SelfSignedCertificate` default to a CNG key storage provider. Accessing the private key through the legacy `$cert.PrivateKey` property returns an incompatible CAPI object that can't perform SHA-256 signing. Fixed by using the `GetRSAPrivateKey()` extension method instead, which correctly returns a CNG-compatible RSA object.

## Outcome

- Root cause of the Server Manager error identified and documented, preventing any risk of an unnecessary/destructive "repair" wizard being run against a working deployment
- Ongoing automated visibility into real RDS broker health, independent of a console view proven to be unreliable for this environment
- A growing historical dataset (hourly CSV entries) that can support future uptime reporting or trend analysis
- Least-privilege alerting: real-time notification on failure, without granting the automation broad tenant-wide mail-send rights

## Tech Stack

- PowerShell 5.1
- Windows Server (Hyper-V guest), Remote Desktop Services (TS Session Broker farm model)
- Windows Internal Database (WID)
- Microsoft Graph API (`Mail.Send`, application permissions)
- Certificate-based OAuth 2.0 client credentials flow (manual JWT construction/signing)
- Exchange Online PowerShell (Application Access Policies)
- Windows Task Scheduler

---

*Part of a broader infrastructure automation portfolio.*
