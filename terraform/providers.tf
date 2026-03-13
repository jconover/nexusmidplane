terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project    = "nexusmidplane"
      environment = var.environment
      owner      = var.owner
      managed_by = "terraform"
    }
  }
}
