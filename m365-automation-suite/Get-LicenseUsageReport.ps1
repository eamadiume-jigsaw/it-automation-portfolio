<#
.SYNOPSIS
    Maps every assigned M365 license to its user, resolving SKU GUIDs to
    readable product names. Flags disabled accounts still holding a license.

.NOTES
    Requires Graph Application permissions: User.Read.All, Organization.Read.All
    Scheduled: weekly
#>

$appId      = "YOUR_APP_ID"
$tenantId   = "YOUR_TENANT_ID"
$thumbprint = "YOUR_CERT_THUMBPRINT"

Connect-MgGraph -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint -NoWelcome

$outputPath = "$HOME\Desktop\Scripts\reports\LicenseUsageReport.csv"

# Build a lookup table so raw SKU GUIDs can be resolved to readable product names
$skus = Get-MgSubscribedSku | Select-Object SkuId, SkuPartNumber
$skuLookup = @{}
foreach ($sku in $skus) {
    $skuLookup[$sku.SkuId] = $sku.SkuPartNumber
}

Get-MgUser -All -Property DisplayName, UserPrincipalName, AssignedLicenses, AccountEnabled |
    ForEach-Object {
        $user = $_
        foreach ($license in $user.AssignedLicenses) {
            [PSCustomObject]@{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                AccountEnabled    = $user.AccountEnabled
                License           = $skuLookup[$license.SkuId]
            }
        }
    } |
    Sort-Object License, DisplayName |
    Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Done. Report saved to $outputPath"

Disconnect-MgGraph | Out-Null
