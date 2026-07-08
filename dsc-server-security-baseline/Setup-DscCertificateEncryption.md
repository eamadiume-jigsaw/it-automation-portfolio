# DSC Credential Encryption Setup

Steps to enable certificate-based credential encryption for DSC, so passwords are never
compiled into a `.mof` file as plaintext.

## 1. Generate a Document Encryption certificate — on the target node

```powershell
$cert = New-SelfSignedCertificate `
    -Type DocumentEncryptionCert `
    -DnsName "DscEncryptionCert" `
    -HashAlgorithm SHA256 `
    -CertStoreLocation Cert:\LocalMachine\My `
    -KeyExportPolicy Exportable `
    -NotAfter (Get-Date).AddYears(2)

$cert.Thumbprint
```

Note the thumbprint — it's needed in two places later.

## 2. Export the public key — on the target node

```powershell
Export-Certificate -Cert $cert -FilePath "C:\Automation\DscPublicKey.cer"
```

## 3. Copy the public key to the management machine

```powershell
$session = New-PSSession -ComputerName TARGET_NODE_IP -Credential $cred
Copy-Item -Path "C:\Automation\DscPublicKey.cer" `
    -Destination "C:\Automation-Local\DscPublicKey.cer" `
    -FromSession $session
```

## 4. Import the public key — on the management machine

```powershell
Import-Certificate -FilePath "C:\Automation-Local\DscPublicKey.cer" `
    -CertStoreLocation Cert:\LocalMachine\My
```

## 5. Configure the target node's LCM to use this certificate for decryption — on the target node

```powershell
Configuration LCMConfig {
    Node "localhost" {
        LocalConfigurationManager {
            CertificateID = "TARGET_NODE_CERT_THUMBPRINT"
        }
    }
}

LCMConfig -OutputPath "C:\LCMConfig"
Set-DscLocalConfigurationManager -Path "C:\LCMConfig" -Verbose
```

## 6. Reference the certificate in `$ConfigData` when compiling

```powershell
$ConfigData = @{
    AllNodes = @(
        @{
            NodeName             = "TARGET_NODE_IP"
            CertificateFile      = "C:\Automation-Local\DscPublicKey.cer"
            Thumbprint           = "TARGET_NODE_CERT_THUMBPRINT"
            PSDscAllowDomainUser = $true
        }
    )
}
```

From this point, any `PSCredential` object referenced inside the configuration
(e.g. a `User` resource's `Password` property) is encrypted at compile time using the
public key, and decrypted only by the target node's private key at apply time.
