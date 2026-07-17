<#
.SYNOPSIS
    Checks the real health of an RD Connection Broker deployment, independent of
    the Server Manager "RDS deployment" view (which only recognizes deployments
    created via the Add Roles and Features wizard and can falsely report
    "no deployment exists" on legacy/farm-based RDS setups).

.DESCRIPTION
    This script verifies RDS broker health by checking the things that actually
    matter for connectivity, rather than relying on Server Manager's UI:
      1. Remote Desktop Connection Broker service (tssdis) status
      2. Windows Internal Database service (WID) status - required if broker
         config is stored locally rather than in a dedicated SQL instance
      3. Recent RD Connection Broker operational log activity (event IDs
         800/801/818/819) to confirm real connection requests are being
         processed successfully
      4. Summary of successful vs failed/timed-out connection attempts in the
         lookback window

    Designed to run standalone or on a schedule via Task Scheduler. Produces a
    console summary, a CSV log entry (appended, for trend tracking over time),
    and a non-zero exit code on failure so Task Scheduler / monitoring tools
    can alert on it.

.PARAMETER LookbackHours
    How many hours back to scan the Session Broker operational log. Default: 24.

.PARAMETER CsvLogPath
    Path to the CSV file that results get appended to for historical tracking.
    Default: C:\IT\Logs\RDSBrokerHealthCheck.csv

.PARAMETER FailureThreshold
    If the percentage of failed/timed-out connection attempts in the lookback
    window meets or exceeds this value, the check is flagged as Warning even
    if services are running. Default: 20 (percent).

.PARAMETER SendAlertOnFailure
    Switch. If set, and the overall status is Warning or Critical, an email
    alert is sent via Microsoft Graph using certificate-based app-only auth
    (same auth pattern as the other Graph automation scripts in this
    portfolio - no client secret stored anywhere).

.PARAMETER TenantId
    Entra ID tenant ID. Required if -SendAlertOnFailure is used.

.PARAMETER ClientId
    App registration (application) ID. The app needs Mail.Send application
    permission, granted admin consent. Required if -SendAlertOnFailure is used.

.PARAMETER CertificateThumbprint
    Thumbprint of the certificate (in the local machine or current user
    certificate store) associated with the app registration. Required if
    -SendAlertOnFailure is used.

.PARAMETER SenderUPN
    The mailbox to send the alert from (must be a real mailbox the app has
    Mail.Send rights to act as, or unrestricted Mail.Send). E.g. an ops/alerts
    shared mailbox.

.PARAMETER AlertRecipients
    One or more email addresses to notify on Warning/Critical.

.EXAMPLE
    .\RDSBrokerHealthCheck.ps1

.EXAMPLE
    .\RDSBrokerHealthCheck.ps1 -LookbackHours 12 -CsvLogPath "D:\Logs\rds-health.csv"

.EXAMPLE
    .\RDSBrokerHealthCheck.ps1 -SendAlertOnFailure `
        -TenantId "xxxx-xxxx" -ClientId "yyyy-yyyy" `
        -CertificateThumbprint "ABCDEF1234567890" `
        -SenderUPN "itops-alerts@execujet.aero" `
        -AlertRecipients "enyioma@execujet.aero","samuel.asibor@execujet.aero"

.NOTES
    Author: Enyioma
    Intended run context: RD Connection Broker server, elevated PowerShell
    (local Administrator or equivalent), or scheduled under a service account
    with local admin rights and "Log on as a batch job" permission.

    Exit codes:
      0 = Healthy
      1 = Warning  (services up, but elevated failure/timeout rate)
      2 = Critical (tssdis or WID service not running)
#>

[CmdletBinding()]
param(
    [int]$LookbackHours = 24,
    [string]$CsvLogPath = "C:\IT\Logs\RDSBrokerHealthCheck.csv",
    [int]$FailureThreshold = 20,

    [switch]$SendAlertOnFailure,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint,
    [string]$SenderUPN,
    [string[]]$AlertRecipients
)

$ErrorActionPreference = 'Stop'
$result = [ordered]@{
    Timestamp             = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName          = $env:COMPUTERNAME
    BrokerServiceStatus   = $null
    WIDServiceStatus      = $null
    TotalConnectionEvents = 0
    SuccessfulLogons      = 0
    FailedOrTimedOut      = 0
    FailureRatePercent    = 0
    OverallStatus         = $null
    Notes                 = ""
}

function Write-Section($Title) {
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Ensure-LogFolder($Path) {
    $folder = Split-Path -Path $Path -Parent
    if ($folder -and -not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

function Get-GraphAppOnlyToken {
    <#
        Certificate-based app-only auth against Microsoft Graph - same
        pattern used across the other Graph automation scripts in this
        portfolio. Builds a signed JWT client assertion from the cert in
        the local certificate store and exchanges it for an access token.
        No client secret is ever stored or transmitted.
    #>
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$CertificateThumbprint
    )

    $cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) {
        $cert = Get-ChildItem -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
    }
    if (-not $cert) {
        throw "Certificate with thumbprint $CertificateThumbprint not found in CurrentUser\My or LocalMachine\My."
    }

    $now      = [DateTimeOffset]::UtcNow
    $exp      = $now.AddMinutes(10).ToUnixTimeSeconds()
    $nbf      = $now.ToUnixTimeSeconds()
    $jti      = [guid]::NewGuid().ToString()
    $x5t      = [Convert]::ToBase64String($cert.GetCertHash()) -replace '\+','-' -replace '/','_' -replace '='

    $header = @{ alg = "RS256"; typ = "JWT"; x5t = $x5t } | ConvertTo-Json -Compress
    $payload = @{
        aud = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        iss = $ClientId
        sub = $ClientId
        jti = $jti
        nbf = $nbf
        exp = $exp
    } | ConvertTo-Json -Compress

    function ConvertTo-Base64Url([string]$InputString) {
        $bytes = [Text.Encoding]::UTF8.GetBytes($InputString)
        [Convert]::ToBase64String($bytes) -replace '\+','-' -replace '/','_' -replace '='
    }

    $encHeader  = ConvertTo-Base64Url $header
    $encPayload = ConvertTo-Base64Url $payload
    $unsigned   = "$encHeader.$encPayload"

    $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
    if (-not $rsa) {
        throw "Could not obtain an RSA private key object from the certificate. Ensure the certificate has an exportable/accessible private key."
    }
    $signatureBytes = $rsa.SignData(
        [Text.Encoding]::UTF8.GetBytes($unsigned),
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $encSignature = [Convert]::ToBase64String($signatureBytes) -replace '\+','-' -replace '/','_' -replace '='
    $jwt = "$unsigned.$encSignature"

    $body = @{
        client_id             = $ClientId
        client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        client_assertion      = $jwt
        scope                 = "https://graph.microsoft.com/.default"
        grant_type            = "client_credentials"
    }

    $tokenResponse = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $body

    return $tokenResponse.access_token
}

function Send-GraphAlertMail {
    param(
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][string]$SenderUPN,
        [Parameter(Mandatory)][string[]]$Recipients,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$BodyHtml
    )

    $toRecipients = $Recipients | ForEach-Object { @{ emailAddress = @{ address = $_ } } }

    $mail = @{
        message = @{
            subject      = $Subject
            body         = @{ contentType = "HTML"; content = $BodyHtml }
            toRecipients = @($toRecipients)
        }
        saveToSentItems = $true
    } | ConvertTo-Json -Depth 6

    Invoke-RestMethod -Method Post `
        -Uri "https://graph.microsoft.com/v1.0/users/$SenderUPN/sendMail" `
        -Headers @{ Authorization = "Bearer $AccessToken" } `
        -ContentType "application/json" `
        -Body $mail
}

# ---------------------------------------------------------------------------
# 1. Service checks
# ---------------------------------------------------------------------------
Write-Section "Service Health"

try {
    $broker = Get-Service -Name "tssdis" -ErrorAction Stop
    $result.BrokerServiceStatus = $broker.Status
    $statusColor = if ($broker.Status -eq 'Running') { 'Green' } else { 'Red' }
    Write-Host "Remote Desktop Connection Broker (tssdis): $($broker.Status)" -ForegroundColor $statusColor
}
catch {
    $result.BrokerServiceStatus = "NotFound"
    Write-Host "Remote Desktop Connection Broker (tssdis): NOT FOUND on this server" -ForegroundColor Red
    $result.Notes += "tssdis service not found on this server. "
}

try {
    $wid = Get-Service -Name "MSSQL`$MICROSOFT##WID" -ErrorAction Stop
    $result.WIDServiceStatus = $wid.Status
    $statusColor = if ($wid.Status -eq 'Running') { 'Green' } else { 'Red' }
    Write-Host "Windows Internal Database (WID): $($wid.Status)" -ForegroundColor $statusColor
}
catch {
    $result.WIDServiceStatus = "NotFound"
    Write-Host "Windows Internal Database (WID): not found (may be using a dedicated SQL instance instead - not necessarily an error)" -ForegroundColor Yellow
    $result.Notes += "WID service not found - broker config may be on dedicated SQL. "
}

# ---------------------------------------------------------------------------
# 2. Recent connection broker activity
# ---------------------------------------------------------------------------
Write-Section "Recent Connection Activity (last $LookbackHours hours)"

$since = (Get-Date).AddHours(-$LookbackHours)
$events = @()

try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = "Microsoft-Windows-TerminalServices-SessionBroker/Operational"
        StartTime = $since
    } -ErrorAction Stop
}
catch {
    Write-Host "Could not read Session Broker operational log: $($_.Exception.Message)" -ForegroundColor Yellow
    $result.Notes += "Could not read operational log. "
}

if ($events.Count -gt 0) {
    # 818 = successful logon, 819 = timed out, 801 = request processed (redirect issued)
    $successes = $events | Where-Object { $_.Id -eq 818 }
    $timeouts  = $events | Where-Object { $_.Id -eq 819 }
    $requests  = $events | Where-Object { $_.Id -eq 800 }

    $result.TotalConnectionEvents = $requests.Count
    $result.SuccessfulLogons      = $successes.Count
    $result.FailedOrTimedOut      = $timeouts.Count

    if (($successes.Count + $timeouts.Count) -gt 0) {
        $result.FailureRatePercent = [math]::Round(
            ($timeouts.Count / ($successes.Count + $timeouts.Count)) * 100, 1
        )
    }

    Write-Host "Connection requests received : $($requests.Count)"
    Write-Host "Successful logons             : $($successes.Count)" -ForegroundColor Green
    Write-Host "Timed out / failed             : $($timeouts.Count)" -ForegroundColor $(if ($timeouts.Count -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host "Failure rate                   : $($result.FailureRatePercent)%"

    if ($successes.Count -gt 0) {
        $lastSuccess = $successes | Sort-Object TimeCreated -Descending | Select-Object -First 1
        Write-Host "Most recent successful logon   : $($lastSuccess.TimeCreated)"
    }
}
else {
    Write-Host "No connection broker events found in the last $LookbackHours hours." -ForegroundColor Yellow
    $result.Notes += "No broker activity in lookback window - could mean no users connected, or logging issue. "
}

# ---------------------------------------------------------------------------
# 3. Overall status
# ---------------------------------------------------------------------------
Write-Section "Overall Status"

$exitCode = 0

if ($result.BrokerServiceStatus -ne 'Running') {
    $result.OverallStatus = "Critical"
    $exitCode = 2
}
elseif ($result.FailureRatePercent -ge $FailureThreshold) {
    $result.OverallStatus = "Warning"
    $exitCode = 1
}
else {
    $result.OverallStatus = "Healthy"
    $exitCode = 0
}

$statusColor = switch ($result.OverallStatus) {
    "Healthy"  { 'Green' }
    "Warning"  { 'Yellow' }
    "Critical" { 'Red' }
}
Write-Host "Status: $($result.OverallStatus)" -ForegroundColor $statusColor

if ($result.Notes) {
    Write-Host "Notes: $($result.Notes)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Note: this check is independent of Server Manager's RDS overview page." -ForegroundColor DarkGray
Write-Host "A legacy/farm-based deployment (e.g. TS Session Broker farm config not" -ForegroundColor DarkGray
Write-Host "created via the Add Roles and Features wizard) can show 'no deployment" -ForegroundColor DarkGray
Write-Host "exists' in Server Manager even while fully functional - this script" -ForegroundColor DarkGray
Write-Host "checks actual service and connection health instead." -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# 4. Log to CSV
# ---------------------------------------------------------------------------
try {
    Ensure-LogFolder -Path $CsvLogPath
    $row = [PSCustomObject]$result
    $writeHeader = -not (Test-Path $CsvLogPath)
    $row | Export-Csv -Path $CsvLogPath -Append -NoTypeInformation -Force
    Write-Host ""
    Write-Host "Result logged to: $CsvLogPath" -ForegroundColor DarkGray
}
catch {
    Write-Host "Warning: could not write to CSV log at $CsvLogPath - $($_.Exception.Message)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 5. Alert on failure (optional)
# ---------------------------------------------------------------------------
if ($SendAlertOnFailure -and $result.OverallStatus -ne "Healthy") {
    Write-Section "Sending Alert"

    $missingParams = @()
    foreach ($p in @('TenantId','ClientId','CertificateThumbprint','SenderUPN','AlertRecipients')) {
        if (-not (Get-Variable -Name $p -ValueOnly -ErrorAction SilentlyContinue)) { $missingParams += $p }
    }

    if ($missingParams.Count -gt 0) {
        Write-Host "Cannot send alert - missing required parameter(s): $($missingParams -join ', ')" -ForegroundColor Yellow
    }
    else {
        try {
            $token = Get-GraphAppOnlyToken -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint

            $statusColorHtml = if ($result.OverallStatus -eq 'Critical') { '#c0392b' } else { '#e67e22' }
            $bodyHtml = @"
<p>RDS Broker Health Check reported <b style="color:$statusColorHtml">$($result.OverallStatus)</b> on <b>$($result.ComputerName)</b>.</p>
<table cellpadding="6" style="border-collapse:collapse;font-family:Segoe UI,Arial,sans-serif;font-size:13px;">
<tr><td><b>Timestamp</b></td><td>$($result.Timestamp)</td></tr>
<tr><td><b>Broker service (tssdis)</b></td><td>$($result.BrokerServiceStatus)</td></tr>
<tr><td><b>WID service</b></td><td>$($result.WIDServiceStatus)</td></tr>
<tr><td><b>Connection requests ($LookbackHours h)</b></td><td>$($result.TotalConnectionEvents)</td></tr>
<tr><td><b>Successful logons</b></td><td>$($result.SuccessfulLogons)</td></tr>
<tr><td><b>Failed / timed out</b></td><td>$($result.FailedOrTimedOut)</td></tr>
<tr><td><b>Failure rate</b></td><td>$($result.FailureRatePercent)%</td></tr>
<tr><td><b>Notes</b></td><td>$($result.Notes)</td></tr>
</table>
"@

            Send-GraphAlertMail -AccessToken $token -SenderUPN $SenderUPN -Recipients $AlertRecipients `
                -Subject "[$($result.OverallStatus)] RDS Broker Health Check - $($result.ComputerName)" `
                -BodyHtml $bodyHtml

            Write-Host "Alert email sent to: $($AlertRecipients -join ', ')" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to send alert email: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

exit $exitCode