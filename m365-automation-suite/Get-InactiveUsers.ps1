<#
.SYNOPSIS
    Exports Entra ID users who have not signed in within the configured threshold.

.NOTES
    Requires Graph Application permissions: User.Read.All, AuditLog.Read.All
    Scheduled: weekly
#>

$appId      = "YOUR_APP_ID"
$tenantId   = "YOUR_TENANT_ID"
$thumbprint = "YOUR_CERT_THUMBPRINT"

Connect-MgGraph -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint -NoWelcome

$cutoffDate = (Get-Date).AddDays(-60)
$outputPath = "$HOME\Desktop\Scripts\reports\InactiveUsers.csv"

Get-MgUser -All -Property DisplayName, UserPrincipalName, SignInActivity, Department |
    Select-Object DisplayName, UserPrincipalName, Department,
        @{N = 'LastSignIn'; E = { $_.SignInActivity.LastSignInDateTime } } |
    Where-Object {
        $_.LastSignIn -eq $null -or [datetime]$_.LastSignIn -lt $cutoffDate
    } |
    Sort-Object LastSignIn |
    Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Done. Report saved to $outputPath"

Disconnect-MgGraph | Out-Null
