terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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
  description = "Short name used to prefix all resources. The cloud-engineer-project-policy scopes its Lambda/DynamoDB/IAM permissions to 'incident-api-*', so changing this means updating that policy too."
  type        = string
  default     = "incident-api"
}

variable "lambda_runtime" {
  description = "Python runtime for all three functions"
  type        = string
  default     = "python3.12"
}
