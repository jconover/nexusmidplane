# Dev environment — cost-optimised sizing (t3.small)
# Apply: terraform apply -var-file=environments/dev/terraform.tfvars

region       = "us-east-2"
environment  = "dev"
owner        = "platform-team"
project_name = "nexusmidplane"

# ── Networking ────────────────────────────────────────────────────────────────

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# ── EC2 ───────────────────────────────────────────────────────────────────────

ec2_linux_instance_type   = "t3.small"   # ~$15/month
ec2_windows_instance_type = "t3.small"   # ~$15/month + Windows license
key_pair_name             = ""           # Use SSM Session Manager instead

# ── DNS / TLS ─────────────────────────────────────────────────────────────────

domain_name     = "dev.nexusmidplane.example.com"
route53_zone_id = ""   # Set to your Route 53 zone ID

# ── VPN ───────────────────────────────────────────────────────────────────────

onprem_public_ip = "0.0.0.0"          # Replace with actual on-prem IP
onprem_cidr      = "192.168.0.0/16"   # Replace with actual on-prem CIDR

# ── Alerting ──────────────────────────────────────────────────────────────────

alert_email = ""   # Optional: set to receive alarm emails
