variable "environment" {
  description = "Environment name: dev, staging, or prod"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "uksouth"
}

variable "vnet_address_space" {
  description = "CIDR block for the virtual network"
  type        = string
}

variable "public_subnet_prefix" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "private_subnet_prefix" {
  description = "CIDR block for the private subnet"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH public key content for VM admin access"
  type        = string
}

variable "allowed_ssh_source_ip" {
  description = "Your public IP allowed to reach the VM via SSH, in CIDR notation (e.g. 102.89.1.1/32)"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}