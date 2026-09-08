terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Short name used to prefix all resources"
  type        = string
  default     = "log-pipeline"
}

variable "api_container_port" {
  description = "Port the FastAPI container listens on"
  type        = number
  default     = 8000
}

variable "allowed_ingress_cidr" {
  description = "CIDR allowed to reach the API on port 8000. Defaults to open -- narrow this to your own IP/32 once you find it, e.g. via 'curl ifconfig.me'."
  type        = string
  default     = "0.0.0.0/0"
}
