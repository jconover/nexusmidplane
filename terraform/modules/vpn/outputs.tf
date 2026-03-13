output "vpn_gateway_id" {
  description = "ID of the Virtual Private Gateway"
  value       = var.enabled ? aws_vpn_gateway.main[0].id : ""
}

output "customer_gateway_id" {
  description = "ID of the Customer Gateway"
  value       = var.enabled ? aws_customer_gateway.onprem[0].id : ""
}

output "vpn_connection_id" {
  description = "ID of the VPN connection"
  value       = var.enabled ? aws_vpn_connection.main[0].id : ""
}

output "tunnel_ips" {
  description = "AWS-side IP addresses for VPN tunnels (tunnel1 and tunnel2)"
  value = var.enabled ? [
    aws_vpn_connection.main[0].tunnel1_address,
    aws_vpn_connection.main[0].tunnel2_address,
  ] : []
}

output "tunnel1_preshared_key" {
  description = "Pre-shared key for VPN tunnel 1 (sensitive)"
  value       = var.enabled ? aws_vpn_connection.main[0].tunnel1_preshared_key : ""
  sensitive   = true
}

output "tunnel2_preshared_key" {
  description = "Pre-shared key for VPN tunnel 2 (sensitive)"
  value       = var.enabled ? aws_vpn_connection.main[0].tunnel2_preshared_key : ""
  sensitive   = true
}
