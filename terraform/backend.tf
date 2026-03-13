# Remote state backend using S3 + DynamoDB for state locking.
#
# SETUP (one-time, before first terraform init):
#   1. Create the S3 bucket:
#      aws s3api create-bucket --bucket nexusmidplane-tfstate-<ACCOUNT_ID> \
#        --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
#      aws s3api put-bucket-versioning --bucket nexusmidplane-tfstate-<ACCOUNT_ID> \
#        --versioning-configuration Status=Enabled
#      aws s3api put-bucket-encryption --bucket nexusmidplane-tfstate-<ACCOUNT_ID> \
#        --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
#   2. Create the DynamoDB table:
#      aws dynamodb create-table --table-name nexusmidplane-tfstate-lock \
#        --attribute-definitions AttributeName=LockID,AttributeType=S \
#        --key-schema AttributeName=LockID,KeyType=HASH \
#        --billing-mode PAY_PER_REQUEST \
#        --region us-east-2
#
#   3. Replace <ACCOUNT_ID> below with your AWS account ID, then run:
#      terraform init

terraform {
  backend "s3" {
    bucket         = "nexusmidplane-tfstate-<ACCOUNT_ID>"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "nexusmidplane-tfstate-lock"
    encrypt        = true
  }
}
