# Remote state backend using S3 with native state locking (use_lockfile).
#
# SETUP (one-time, before first terraform init):
#   1. Bootstrap the state bucket:
#      cd bootstrap && terraform init && terraform apply
#
#   2. Copy the example backend config and fill in the bucket name from bootstrap output:
#      cp backend.tfbackend.example backend.tfbackend
#      # Edit backend.tfbackend — set bucket = "nexusmidplane-tfstate-<YOUR_ACCOUNT_ID>"
#
#   3. Initialize Terraform with backend config:
#      terraform init -backend-config=backend.tfbackend

terraform {
  backend "s3" {
    # bucket is provided via -backend-config=backend.tfbackend (gitignored)
    key          = "terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
