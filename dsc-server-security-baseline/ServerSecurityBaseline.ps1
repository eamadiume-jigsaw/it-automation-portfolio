<#
.SYNOPSIS
    DSC configuration: server security baseline for a remote Windows Server node.

.NOTES
    Prerequisites (see Setup-DscCertificateEncryption.md):
      - NetworkingDsc module installed on BOTH the management machine and the
        target node (target needs -Scope AllUsers, since LCM runs as SYSTEM)
      - A Document Encryption certificate generated on the target node, with its
        public key imported into the management machine's certificate store
      - Target node's LCM meta-configuration set to the matching certificate
        thumbprint (see Set-LcmCertificate.ps1)

.EXAMPLE
    . .\ServerSecurityBaseline.ps1
    $BreakGlassCred = Get-Credential -UserName "svc-breakglass"
    ServerSecurityBaseline -OutputPath "C:\ServerSecurityBaseline-MOF" -ConfigurationData $ConfigData
    $cred = Get-Credential   # target node's own admin credential
    Start-DscConfiguration -Path "C:\ServerSecurityBaseline-MOF" -Wait -Verbose -Credential $cred
#>

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName             = "TARGET_NODE_IP_OR_HOSTNAME"
            CertificateFile      = "C:\Automation-Local\DscPublicKey.cer"
            Thumbprint           = "TARGET_NODE_CERT_THUMBPRINT"
            PSDscAllowDomainUser = $true
        }
    )
}

Configuration ServerSecurityBaseline {

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName NetworkingDsc

    Node "TARGET_NODE_IP_OR_HOSTNAME" {

        # ---- Standard folder structure ----
        File AutomationFolder {
            Ensure          = "Present"
            Type            = "Directory"
            DestinationPath = "C:\Automation"
        }

        File LogFolder {
            Ensure          = "Present"
            Type            = "Directory"
            DestinationPath = "C:\Automation\ITLogs"
            DependsOn       = "[File]AutomationFolder"
        }

        # ---- Remove legacy insecure features ----
        WindowsFeature Telnet {
            Ensure = "Absent"
            Name   = "Telnet-Client"
        }

        WindowsFeature SMB1 {
            Ensure = "Absent"
            Name   = "FS-SMB1"
        }

        # ---- Registry-based security hardening ----
        # Ensures AutoAdminLogon is disabled (prevents plaintext credential storage
        # in the registry — a common finding in security audits)
        Registry DisableAutoAdminLogon {
            Ensure    = "Present"
            Key       = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            ValueName = "AutoAdminLogon"
            ValueData = "0"
            ValueType = "String"
        }

        # ---- Firewall enforcement (defense-in-depth alongside feature removal) ----
        Firewall BlockTelnetPort {
            Name        = "Block-Telnet-23"
            DisplayName = "Block Legacy Telnet Port 23"
            Ensure      = "Present"
            Enabled     = "True"
            Direction   = "Inbound"
            LocalPort   = "23"
            Protocol    = "TCP"
            Action      = "Block"
        }

        # ---- Service assurance ----
        Service SpoolerCheck {
            Name  = "Spooler"
            State = "Running"
        }

        # ---- Governed local break-glass admin account ----
        User BreakGlassAdmin {
            Ensure               = "Present"
            UserName             = "svc-breakglass"
            FullName             = "Break Glass Admin"
            Description          = "Emergency local admin account - credentials stored securely offline"
            Password             = $BreakGlassCred
            PasswordNeverExpires = $true
            Disabled             = $false
            DependsOn            = "[File]AutomationFolder"
        }

        Group AdminGroupMembership {
            GroupName        = "Administrators"
            Ensure           = "Present"
            MembersToInclude = "svc-breakglass"
            DependsOn        = "[User]BreakGlassAdmin"
        }
    }
}
