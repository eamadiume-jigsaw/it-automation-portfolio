# Secure Multi-Environment Azure Infrastructure (Terraform)

A reusable Terraform module for provisioning a secure, isolated Azure environment — VNet with public/private subnet separation, least-privilege Network Security Groups, a VM in the private subnet, and a storage account for logging/backup — designed to deploy identically and repeatably across dev, staging, and production with zero manual configuration steps.

## The problem

A small company needs a secure, repeatable cloud environment they can deploy consistently across development, staging, and production without manual configuration steps that introduce human error.

## Architecture

                    Internet
                        |
                 NSG (public subnet)
                        |
    +--------------------------------------+
    |              Public Subnet            |
    +--------------------------------------+
                        |
    +--------------------------------------+
    |             Private Subnet            |
    |         - VM (least-privilege NSG)    |
    +--------------------------------------+

    Storage Account (logging/backup, private)
    Remote Terraform state (Azure Blob Storage)

    
## Design: one module, environment-specific inputs, isolated state

Rather than three separate copies of the same infrastructure code (an approach that inevitably drifts and introduces manual error over time), this project uses a **single reusable module** (`modules/environment`) called by three thin environment configs (`environments/dev`, `environments/staging`, `environments/prod`), each supplying its own `.tfvars` file with environment-specific values — CIDR ranges, VM size, and the allowed SSH source IP.

Each environment maintains its **own, fully isolated Terraform state file** in the same Azure Blob Storage container, distinguished by blob key (`dev.terraform.tfstate`, `staging.terraform.tfstate`, `prod.terraform.tfstate`). This was a deliberate choice over Terraform Workspaces: separate state files make it structurally impossible to accidentally `apply` a change intended for dev against production, since each environment is a genuinely separate root configuration pointed at a separate state path.

## Design: least privilege at the network layer

Two separate Network Security Groups enforce network isolation, not just naming convention:

- The **public subnet's NSG** allows inbound SSH only from a specific, configurable IP address, and explicitly denies all other inbound traffic.
- The **private subnet's NSG** allows inbound SSH only from the public subnet's own CIDR range — never from the internet directly. The VM's network interface has no public IP address at all, making it structurally unreachable from outside the VNet, not just firewalled.
- Both NSGs include an explicit `DenyAllOtherInbound` rule at the lowest priority, even though Azure NSGs deny by default — this makes the security posture visible in code rather than relying on an implicit platform default a reviewer would need to already know.

The storage account similarly sets `public_network_access_enabled = false`, mirroring the same "private by default, no public exposure without a deliberate decision" principle applied throughout.

## Bootstrapping remote state

Terraform's Azure Blob backend requires the storage account and container to exist *before* Terraform can use them to store state — a genuine chicken-and-egg problem. This was resolved with a one-time manual bootstrap via Azure CLI (not tracked in this project's Terraform state, since it exists to support that state):

```powershell
az group create --name rg-terraform-state --location uksouth
az storage account create --name <unique-name> --resource-group rg-terraform-state --location uksouth --sku Standard_LRS --encryption-services blob
az storage container create --name tfstate --account-name <unique-name>
```

## Known issues and how they were resolved

**Azure Resource Manager propagation lag.** Early applies repeatedly failed with errors like `ResourceNotFound` or `Provider produced inconsistent result after apply` when a resource (e.g. a subnet) was created referencing a parent resource (e.g. a VNet) that Terraform believed existed but Azure's API hadn't yet fully propagated. This is a documented Azure behavior, more pronounced on free-tier subscriptions. Resolved by inserting explicit `time_sleep` resources between dependency-heavy stages (after the resource group, after the VNet, after the subnets), forcing Terraform to pause rather than race ahead of Azure's eventual consistency.

**Parallel resource creation exacerbating the above.** Terraform's default behavior of creating up to 10 resources simultaneously worsened the propagation-lag issue on this subscription, causing near-simultaneous "inconsistent result" errors across unrelated resources. Resolved by applying with `-parallelism=1`, forcing strictly sequential resource creation. This significantly increases apply time but eliminated the race condition entirely.

**VM SKU unavailable across every tested size and region.** `Standard_B2s`, `Standard_B1s`, and `Standard_A2_v2` all failed with `SkuNotAvailable` in `uksouth`, and `westeurope` rejected all resource creation outright with `RequestDisallowedByAzure` ("region not accepting new customers"). Rather than continue guessing sizes, this was diagnosed properly: `az vm list-usage --location uksouth` confirmed real quota limits existed (4 vCPUs per family) rather than zero, ruling out a hard quota block; the Azure Portal's VM size picker then confirmed every size — including `B1s`, the size the free tier is specifically built around — showed as unavailable for this specific subscription. This matches Azure's documented behavior of restricting new free-trial subscriptions to a limited VM SKU allowlist for an initial period after account creation, independent of regional capacity. Networking and storage components were fully validated and torn down cleanly; VM validation is pending the restriction lifting.

## Setup

1. Bootstrap remote state (see above, one-time)
2. `cd environments/dev`
3. Update `dev.tfvars`: SSH public key, current public IP, CIDR ranges as needed
4. `terraform init`
5. `terraform plan -var-file="dev.tfvars"`
6. `terraform apply -var-file="dev.tfvars" -parallelism=1`
7. `terraform destroy -var-file="dev.tfvars" -parallelism=1` when done

Repeat identically for `staging` and `prod`, each with their own `.tfvars` values — no code changes required between environments.