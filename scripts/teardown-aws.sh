#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# teardown-aws.sh — Safely destroy AWS resources
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { error "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/terraform"
ENVIRONMENT="${1:-dev}"

# ── Safety confirmation ──────────────────────────────────────
confirm_destroy() {
  echo ""
  echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║           ⚠️  DESTRUCTIVE OPERATION ⚠️            ║${NC}"
  echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  warn "This will PERMANENTLY DESTROY all AWS resources for environment: ${ENVIRONMENT}"
  echo ""
  echo "  Resources to be destroyed:"
  echo "    - EC2 instances (Java + .NET app servers)"
  echo "    - Application Load Balancer"
  echo "    - VPC, subnets, security groups"
  echo "    - S3 bucket contents (artifacts)"
  echo "    - IAM roles and policies"
  echo ""
  echo -e "${YELLOW}Estimated cost savings: ~\$50-200/month${NC}"
  echo ""

  read -r -p "Type 'destroy' to confirm: " confirmation
  if [[ "$confirmation" != "destroy" ]]; then
    info "Teardown cancelled."
    exit 0
  fi

  echo ""
  read -r -p "Final confirmation — environment '${ENVIRONMENT}'. Continue? (yes/no): " final
  if [[ "$final" != "yes" ]]; then
    info "Teardown cancelled."
    exit 0
  fi
}

# ── Pre-checks ───────────────────────────────────────────────
check_prereqs() {
  command -v terraform &>/dev/null || die "terraform not found."
  command -v aws       &>/dev/null || die "aws-cli not found."

  info "Checking AWS credentials..."
  aws sts get-caller-identity --output table || die "AWS credentials not configured. Run: aws configure"
}

# ── Empty S3 bucket (required before destroy) ────────────────
empty_s3_bucket() {
  local bucket_name
  bucket_name=$(terraform -chdir="$TF_DIR" output -raw artifacts_bucket_name 2>/dev/null || true)

  if [[ -n "$bucket_name" ]]; then
    warn "Emptying S3 bucket: $bucket_name (required before Terraform destroy)"
    aws s3 rm "s3://${bucket_name}" --recursive || warn "Failed to empty bucket — may already be empty."
  fi
}

# ── Terraform destroy ────────────────────────────────────────
terraform_destroy() {
  info "Initializing Terraform..."
  cd "$TF_DIR"

  local tfvars="environments/${ENVIRONMENT}/terraform.tfvars"
  [[ -f "$tfvars" ]] || die "tfvars not found: $TF_DIR/$tfvars"

  terraform init

  info "Running terraform destroy for environment: ${ENVIRONMENT}..."
  terraform destroy \
    -var-file="$tfvars" \
    -auto-approve

  info "Terraform destroy complete."
  cd "$PROJECT_ROOT"
}

# ── Post-destroy reminder ─────────────────────────────────────
post_destroy_reminder() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════════${NC}"
  info "AWS teardown complete for environment: ${ENVIRONMENT}"
  echo ""
  echo "  Remember to also:"
  echo "    □ Delete Terraform state from S3 if no longer needed:"
  echo "      aws s3 rm s3://\$TF_STATE_BUCKET/nexusmidplane/${ENVIRONMENT}/ --recursive"
  echo "    □ Remove GitHub Actions secrets if decommissioning permanently"
  echo "    □ Delete the OIDC IAM role if no longer needed"
  echo "    □ Check for orphaned EBS volumes: aws ec2 describe-volumes --filters Name=status,Values=available"
  echo ""
  warn "On-prem Docker stack NOT affected. Run 'docker compose down' separately if desired."
  echo -e "${CYAN}══════════════════════════════════════════${NC}"
}

# ── Main ─────────────────────────────────────────────────────
main() {
  echo "NexusMidplane — AWS Teardown"
  echo "Environment: ${ENVIRONMENT}"
  echo ""

  check_prereqs
  confirm_destroy
  empty_s3_bucket
  terraform_destroy
  post_destroy_reminder
}

main "$@"
