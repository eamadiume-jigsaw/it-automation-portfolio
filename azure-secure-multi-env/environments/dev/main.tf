terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "eamadiumetfstate01"
    container_name        = "tfstate"
    key                   = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

module "environment" {
  source = "../../modules/environment"

  environment            = var.environment
  location               = var.location
  vnet_address_space     = var.vnet_address_space
  public_subnet_prefix   = var.public_subnet_prefix
  private_subnet_prefix  = var.private_subnet_prefix
  vm_size                = var.vm_size
  admin_username         = var.admin_username
  admin_ssh_public_key   = var.admin_ssh_public_key
  allowed_ssh_source_ip  = var.allowed_ssh_source_ip
  tags                   = var.tags
}