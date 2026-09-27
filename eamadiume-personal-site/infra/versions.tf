terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Same state bucket as the ci-cd-pipeline project, separate key.
  backend "s3" {
    bucket       = "eamadiume-cicd-tfstate"
    key          = "eamadiume-site/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = { Project = "eamadiume-site", ManagedBy = "terraform" }
  }
}

# CloudFront only accepts ACM certificates from us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = { Project = "eamadiume-site", ManagedBy = "terraform" }
  }
}
