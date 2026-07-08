<#
.SYNOPSIS
    Reusable certificate-based app-only connection to Microsoft Graph.
    Include this block at the top of any script that needs unattended Graph access.

.NOTES
    Requires an Entra ID App Registration with:
      - Application (not Delegated) permissions granted for whatever Graph scopes
        the calling script needs, with admin consent
      - A certificate uploaded under Certificates & Secrets, matching the
        thumbprint below (private key must be present in the local cert store
        of the machine running this script)
#>

$appId      = "YOUR_APP_ID"
$tenantId   = "YOUR_TENANT_ID"
$thumbprint = "YOUR_CERT_THUMBPRINT"

Connect-MgGraph -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint -NoWelcome
