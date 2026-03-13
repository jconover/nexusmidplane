# Prod environment — production sizing (t3.medium)
# Apply: terraform apply -var-file=environments/prod/terraform.tfvars
# NOTE: Review and set all placeholder values before applying to production.

region       = "us-east-2"
environment  = "prod"
owner        = "platform-team"
project_name = "nexusmidplane"

# ── Networking ────────────────────────────────────────────────────────────────

vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]

# ── EC2 ───────────────────────────────────────────────────────────────────────

ec2_linux_instance_type   = "t3.medium"  # ~$30/month
ec2_windows_instance_type = "t3.medium"  # ~$30/month + Windows license
key_pair_name             = ""           # Set to your key pair name for emergency access

# ── DNS / TLS ─────────────────────────────────────────────────────────────────

domain_name     = "nexusmidplane.example.com"
route53_zone_id = ""   # REQUIRED: Set to your Route 53 zone ID before applying

# ── VPN ───────────────────────────────────────────────────────────────────────

onprem_public_ip = "0.0.0.0"          # REQUIRED: Replace with actual on-prem IP
onprem_cidr      = "192.168.0.0/16"   # REQUIRED: Replace with actual on-prem CIDR

# ── Alerting ──────────────────────────────────────────────────────────────────

alert_email = ""   # REQUIRED: Set to ops/on-call email for production alerts
