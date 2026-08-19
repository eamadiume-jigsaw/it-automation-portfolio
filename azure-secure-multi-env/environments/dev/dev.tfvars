environment            = "dev"
location               = "uksouth"
vnet_address_space     = "10.10.0.0/16"
public_subnet_prefix   = "10.10.1.0/24"
private_subnet_prefix  = "10.10.2.0/24"
vm_size                = "Standard_B1s"
admin_username         = "azureadmin"
admin_ssh_public_key   = "ssh-rsa AAAA...your-public-key-here"
allowed_ssh_source_ip  = "YOUR.PUBLIC.IP.HERE/32"

tags = {
  environment = "dev"
  project     = "azure-secure-environment"
  managed_by  = "terraform"
}