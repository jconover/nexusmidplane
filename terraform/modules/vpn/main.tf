# VPN module — site-to-site VPN connecting AWS VPC to on-premises network.
# Uses static routing (no BGP required) for simplicity.
# Two tunnels are created automatically by AWS for redundancy.

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── Virtual Private Gateway ───────────────────────────────────────────────────

resource "aws_vpn_gateway" "main" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-vgw"
  }
}

# Attach VGW to VPC
resource "aws_vpn_gateway_attachment" "main" {
  vpc_id         = var.vpc_id
  vpn_gateway_id = aws_vpn_gateway.main.id
}

# ── Customer Gateway ──────────────────────────────────────────────────────────
# Represents the on-premises VPN device

resource "aws_customer_gateway" "onprem" {
  bgp_asn    = var.bgp_asn
  ip_address = var.onprem_public_ip
  type       = "ipsec.1"

  tags = {
    Name     = "${local.name_prefix}-cgw"
    location = "on-premises"
  }
}

# ── VPN Connection ────────────────────────────────────────────────────────────

resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.onprem.id
  type                = "ipsec.1"
  static_routes_only  = true # Static routing; no BGP required on-prem

  # IKEv2 is preferred; AWS supports both IKEv1 and IKEv2
  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  tags = {
    Name = "${local.name_prefix}-vpn-connection"
  }
}

# ── Static Route ──────────────────────────────────────────────────────────────
# Route on-prem CIDR traffic through the VPN connection

resource "aws_vpn_connection_route" "onprem" {
  destination_cidr_block = var.onprem_cidr
  vpn_connection_id      = aws_vpn_connection.main.id
}

# ── Route Table Propagation ───────────────────────────────────────────────────
# Allow VGW to propagate routes to private route tables automatically.
# This data source looks up route tables in the VPC tagged as private.

data "aws_route_tables" "private" {
  vpc_id = var.vpc_id

  filter {
    name   = "tag:tier"
    values = ["private"]
  }
}

resource "aws_vpn_gateway_route_propagation" "private" {
  for_each       = toset(data.aws_route_tables.private.ids)
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = each.value
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "tunnel1_state" {
  alarm_name          = "${local.name_prefix}-vpn-tunnel1-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TunnelState"
  namespace           = "AWS/VPN"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "VPN tunnel 1 is down"

  dimensions = {
    VpnId         = aws_vpn_connection.main.id
    TunnelIpAddress = aws_vpn_connection.main.tunnel1_address
  }

  tags = {
    Name = "${local.name_prefix}-vpn-tunnel1-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "tunnel2_state" {
  alarm_name          = "${local.name_prefix}-vpn-tunnel2-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TunnelState"
  namespace           = "AWS/VPN"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "VPN tunnel 2 is down"

  dimensions = {
    VpnId           = aws_vpn_connection.main.id
    TunnelIpAddress = aws_vpn_connection.main.tunnel2_address
  }

  tags = {
    Name = "${local.name_prefix}-vpn-tunnel2-alarm"
  }
}
