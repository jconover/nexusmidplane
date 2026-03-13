variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "owner" {
  description = "Team or individual owning these resources (used for tagging)"
  type        = string
  default     = "platform-team"
}

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "nexusmidplane"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

variable "ec2_linux_instance_type" {
  description = "Instance type for the WildFly (Amazon Linux 2023) host"
  type        = string
  default     = "t3.small"
}

variable "ec2_windows_instance_type" {
  description = "Instance type for the IIS (Windows Server 2022) host"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair for SSH/RDP emergency access"
  type        = string
  default     = ""
}

# ── DNS / TLS ─────────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Public domain name for the ALB (e.g. nexusmidplane.example.com)"
  type        = string
  default     = "nexusmidplane.example.com"
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for DNS validation of ACM certificate"
  type        = string
  default     = ""
}

# ── VPN ───────────────────────────────────────────────────────────────────────

variable "onprem_public_ip" {
  description = "Public IP of the on-premises VPN endpoint"
  type        = string
  default     = "0.0.0.0" # Replace with actual on-prem IP
}

variable "onprem_cidr" {
  description = "CIDR block of the on-premises network"
  type        = string
  default     = "192.168.0.0/16"
}

# ── Alerting ──────────────────────────────────────────────────────────────────

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = ""
}
