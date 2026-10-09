# providers.tf
# ##############################
# Providers
# ##############################
terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

# ##############################
# AWS
# ##############################
provider "aws" {
  region = local.aws_region

  default_tags {
    tags = local.default_tags
  }
}
