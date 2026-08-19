variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "vnet_address_space" {
  type = string
}

variable "public_subnet_prefix" {
  type = string
}

variable "private_subnet_prefix" {
  type = string
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_ssh_public_key" {
  type = string
}

variable "allowed_ssh_source_ip" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}