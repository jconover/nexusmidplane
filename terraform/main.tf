# Root module — wires child modules together.
# Data flows: vpc → ec2-linux/ec2-windows/alb/vpn
#             acm → alb
#             ec2-linux/ec2-windows → alb target groups
#             ec2-linux/ec2-windows → cloudwatch

# ── VPC ───────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
  project_name         = var.project_name
}

# ── ACM Certificate ───────────────────────────────────────────────────────────

module "acm" {
  source = "./modules/acm"

  domain_name = var.domain_name
  zone_id     = var.route53_zone_id
  environment = var.environment
  project_name = var.project_name
}

# ── Secrets Manager ───────────────────────────────────────────────────────────

module "secrets" {
  source = "./modules/secrets"

  environment  = var.environment
  project_name = var.project_name
}

# ── EC2: WildFly (Amazon Linux 2023) ──────────────────────────────────────────

module "ec2_linux" {
  source = "./modules/ec2-linux"

  instance_type = var.ec2_linux_instance_type
  subnet_id     = module.vpc.private_subnet_ids[0]
  vpc_id        = module.vpc.vpc_id
  vpc_cidr      = module.vpc.vpc_cidr_block
  key_pair_name = var.key_pair_name
  environment   = var.environment
  project_name  = var.project_name
}

# ── EC2: IIS (Windows Server 2022) ────────────────────────────────────────────

module "ec2_windows" {
  source = "./modules/ec2-windows"

  instance_type = var.ec2_windows_instance_type
  subnet_id     = module.vpc.private_subnet_ids[1]
  vpc_id        = module.vpc.vpc_id
  vpc_cidr      = module.vpc.vpc_cidr_block
  key_pair_name = var.key_pair_name
  environment   = var.environment
  project_name  = var.project_name
}

# ── ALB ───────────────────────────────────────────────────────────────────────

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn
  linux_instance_id = module.ec2_linux.instance_id
  windows_instance_id = module.ec2_windows.instance_id
  environment       = var.environment
  project_name      = var.project_name
}

# ── CloudWatch ────────────────────────────────────────────────────────────────

module "cloudwatch" {
  source = "./modules/cloudwatch"

  linux_instance_id   = module.ec2_linux.instance_id
  windows_instance_id = module.ec2_windows.instance_id
  environment         = var.environment
  project_name        = var.project_name
  alert_email         = var.alert_email
  region              = var.region
}

# ── VPN ───────────────────────────────────────────────────────────────────────

module "vpn" {
  source = "./modules/vpn"

  enabled                = var.onprem_public_ip != "0.0.0.0"
  vpc_id                 = module.vpc.vpc_id
  private_route_table_id = module.vpc.private_route_table_id
  onprem_public_ip       = var.onprem_public_ip
  onprem_cidr            = var.onprem_cidr
  environment            = var.environment
  project_name           = var.project_name
}
