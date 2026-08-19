environment            = "dev"
location               = "uksouth"
vnet_address_space     = "10.10.0.0/16"
public_subnet_prefix   = "10.10.1.0/24"
private_subnet_prefix  = "10.10.2.0/24"
vm_size                = "Standard_A2_v2"
admin_username         = "azureadmin"
admin_ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+j5VOZ4OWXKG0wLug/7EUWofDLpfLXL9muqYfOxZRJtT2IcSKWqhKc63WvixCcxBFU8X8IlBQdrQ+69j60GmWnSTIclbzoGMG0qx6ZcM2VxePFVc6laRzSDFqQX2v4LDeYwwpQqexceMBrAqyv8Foh/bjJrTMVssFgXUwgV//C0qdpdLhw1OGbxOXPS02A7eub9gk1bGSBRgkzbR5/Aq0SYvfi43D7aCNo7yaRSL5ikmS5E8l2rTZ9PVLXxki79nit7vxLr4WyBQU2CfQTbc5Shgb2Z70rNy65NWMJ2I9mMYKAGJEbQH2FKuOfEbLu0La0QOqezV3h+v0fS6kdl3r"
allowed_ssh_source_ip  = "169.239.48.172/32"

tags = {
  environment = "dev"
  project     = "azure-secure-environment"
  managed_by  = "terraform"
}