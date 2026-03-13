# ── ALB ───────────────────────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

output "wildfly_private_ip" {
  description = "Private IP of the WildFly (Linux) instance"
  value       = module.ec2_linux.private_ip
}

output "iis_private_ip" {
  description = "Private IP of the IIS (Windows) instance"
  value       = module.ec2_windows.private_ip
}

# ── VPC ───────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# ── VPN ───────────────────────────────────────────────────────────────────────

output "vpn_tunnel_ips" {
  description = "AWS-side VPN tunnel IPs"
  value       = module.vpn.tunnel_ips
}

# ── Secrets ───────────────────────────────────────────────────────────────────

output "wildfly_secret_arn" {
  description = "ARN of the WildFly admin credentials secret"
  value       = module.secrets.wildfly_secret_arn
  sensitive   = true
}
