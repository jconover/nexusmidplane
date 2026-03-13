# Bootstrap — creates the S3 bucket for Terraform remote state.
# Uses local state (no remote backend needed).
#
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#
# After this completes, go back to terraform/ and run:
#   terraform init -backend-config=backend.tfbackend

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "nexusmidplane-tfstate-${data.aws_caller_identity.current.account_id}"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project    = "nexusmidplane"
      managed_by = "terraform-bootstrap"
    }
  }
}

variable "region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-2"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state — use this in backend.tfbackend"
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  description = "ARN of the state bucket"
  value       = aws_s3_bucket.tfstate.arn
}
