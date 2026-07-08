# DSC Server Security Baseline

A PowerShell Desired State Configuration (DSC) baseline that remotely provisions and
hardens a Windows Server target — combining feature removal, firewall enforcement,
registry hardening, service assurance, and governed local account creation, with
encrypted credential handling.

## Problem

New server builds typically go through a manual hardening checklist (disable legacy
protocols, configure firewall rules, set specific registry values, create a governed
break-glass admin account). This is repetitive, easy to get inconsistent across
machines, and hard to audit after the fact. DSC solves this by making the baseline
**declarative and re-checkable**: define the desired end state once, and re-apply or
verify it against any number of servers.

## What the baseline enforces

| Resource type | Enforcement |
|---|---|
| `WindowsFeature` | Removes Telnet Client and the SMB1 protocol feature |
| `Registry` | Disables `AutoAdminLogon` (prevents a plaintext credential being stored in the registry) |
| `Firewall` (NetworkingDsc) | Blocks inbound TCP port 23 (legacy Telnet), defense-in-depth alongside feature removal |
| `Service` | Ensures the Print Spooler service is running |
| `File` | Creates a standard `C:\Automation` folder structure for scripts/logs |
| `User` + `Group` | Provisions a governed local "break-glass" admin account and confirms Administrators group membership |

## Why this matters more than a plain script

A plain imperative script ("run these commands once") doesn't self-verify or
self-heal. DSC is **idempotent**: re-running the same configuration against a target
that's already compliant does nothing (verified — see "Skip Set" behavior in DSC logs),
and if configuration drifts (e.g. someone re-enables a service or deletes a folder),
re-applying the same `.mof` restores the intended state.

## Credential security design

The `User` resource requires a password — and DSC deliberately **refuses to compile a
plaintext password into a `.mof` file** by default. This project uses the production-
correct approach rather than the common `PSDscAllowPlainTextPassword` shortcut:

1. A **Document Encryption certificate** is generated *on the target node* (not the
   management machine) — this is what will eventually decrypt the credential.
2. The certificate's **public key only** is exported and imported into the management
   machine's certificate store.
3. The management machine compiles the configuration, encrypting the password using
   that public key.
4. The target node's Local Configuration Manager (LCM) is configured via a
   meta-configuration to know which certificate thumbprint to use for decryption.
5. At apply time, the encrypted credential travels over the network and is decrypted
   only by the target node, using its own private key — the private key never leaves
   the target machine.

See `Setup-DscCertificateEncryption.md` for the full step-by-step.

## Architecture

```
Management PC                              Target Server (Node)
──────────────                              ────────────────────
Write Configuration (.ps1)
        │
        ▼
Compile with -ConfigurationData
(encrypts credential using
 target's public key)   ──────────────►     Receives encrypted .mof
        │                                            │
        ▼                                            ▼
Start-DscConfiguration              LCM decrypts credential using
        │                            private key, applies all
        ▼                            resources (File, WindowsFeature,
   (over WinRM)                      Registry, Firewall, Service,
                                      User, Group)
```

## Real problems solved during build

- **WinRM/firewall block on "Public" network profile** — `winrm quickconfig` failed
  until the network adapter's profile was corrected; resolved by adjusting the network
  category and re-running the firewall exception step.
- **UAC remote token filtering** — local admin credentials get a filtered (non-admin)
  token by default over remote connections to non-domain-joined machines; a local
  admin can authenticate but be denied write access. Documented workaround:
  `LocalAccountTokenFilterPolicy` registry setting.
- **Module scope mismatch** — a Gallery-installed DSC resource module (`NetworkingDsc`)
  worked at compile time but failed at apply time on the remote node because it was
  only installed for the current user, not system-wide (`-Scope AllUsers` required,
  since the target's LCM runs as SYSTEM).
- **DSC resource dependency ordering** — nested folder resources use explicit
  `DependsOn` references to guarantee parent folders are created before child paths
  are evaluated.

## Setup

See `Setup-DscCertificateEncryption.md` for certificate generation and LCM
meta-configuration steps, then run `ServerSecurityBaseline.ps1` following the inline
comments. All tenant/host-specific values (IP address, thumbprints) are placeholders.
