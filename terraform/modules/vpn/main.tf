# VPN module — site-to-site VPN connecting AWS VPC to on-premises network.
# Uses static routing (no BGP required) for simplicity.
# Two tunnels are created automatically by AWS for redundancy.
# Set enabled = false to skip creation (e.g. when no real on-prem IP exists).

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── Virtual Private Gateway ───────────────────────────────────────────────────

resource "aws_vpn_gateway" "main" {
  count  = var.enabled ? 1 : 0
  vpc_id = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-vgw"
  }
}

# Attach VGW to VPC
resource "aws_vpn_gateway_attachment" "main" {
  count          = var.enabled ? 1 : 0
  vpc_id         = var.vpc_id
  vpn_gateway_id = aws_vpn_gateway.main[0].id
}

# ── Customer Gateway ──────────────────────────────────────────────────────────
# Represents the on-premises VPN device

resource "aws_customer_gateway" "onprem" {
  count      = var.enabled ? 1 : 0
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
  count               = var.enabled ? 1 : 0
  vpn_gateway_id      = aws_vpn_gateway.main[0].id
  customer_gateway_id = aws_customer_gateway.onprem[0].id
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
  count                  = var.enabled ? 1 : 0
  destination_cidr_block = var.onprem_cidr
  vpn_connection_id      = aws_vpn_connection.main[0].id
}

# ── Route Table Propagation ───────────────────────────────────────────────────
# Allow VGW to propagate routes to private route tables automatically.

resource "aws_vpn_gateway_route_propagation" "private" {
  count          = var.enabled ? 1 : 0
  vpn_gateway_id = aws_vpn_gateway.main[0].id
  route_table_id = var.private_route_table_id
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "tunnel1_state" {
  count               = var.enabled ? 1 : 0
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
    VpnId           = aws_vpn_connection.main[0].id
    TunnelIpAddress = aws_vpn_connection.main[0].tunnel1_address
  }

  tags = {
    Name = "${local.name_prefix}-vpn-tunnel1-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "tunnel2_state" {
  count               = var.enabled ? 1 : 0
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
    VpnId           = aws_vpn_connection.main[0].id
    TunnelIpAddress = aws_vpn_connection.main[0].tunnel2_address
  }

  tags = {
    Name = "${local.name_prefix}-vpn-tunnel2-alarm"
  }
}
