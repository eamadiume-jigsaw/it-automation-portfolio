<#
.SYNOPSIS
    Exports Intune-managed devices that are non-compliant or have not synced
    within the configured threshold.

.NOTES
    Requires Graph Application permission: DeviceManagementManagedDevices.Read.All
    Scheduled: daily
#>

$appId      = "YOUR_APP_ID"
$tenantId   = "YOUR_TENANT_ID"
$thumbprint = "YOUR_CERT_THUMBPRINT"

Connect-MgGraph -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint -NoWelcome

$cutoffDate = (Get-Date).AddDays(-14)
$outputPath = "$HOME\Desktop\Scripts\reports\IntuneComplianceReport.csv"

Get-MgDeviceManagementManagedDevice -All |
    Select-Object DeviceName, UserPrincipalName, ComplianceState, OperatingSystem,
        @{N = 'LastSync'; E = { [datetime]$_.LastSyncDateTime } } |
    Where-Object {
        $_.ComplianceState -ne 'compliant' -or $_.LastSync -lt $cutoffDate
    } |
    Sort-Object LastSync |
    Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Done. Report saved to $outputPath"

Disconnect-MgGraph | Out-Null
