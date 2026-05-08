terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Uncomment after first apply and set backend bucket
  # backend "s3" {
  #   bucket         = "photo-scanner-tfstate-${var.environment}"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "photo-scanner"
      ManagedBy   = "Terraform"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Local variables for naming consistency
locals {
  app_name         = "photo-scanner"
  namespace        = "${local.app_name}-${var.environment}"
  common_tags      = var.tags
}
