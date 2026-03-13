output "vpn_gateway_id" {
  description = "ID of the Virtual Private Gateway"
  value       = aws_vpn_gateway.main.id
}

output "customer_gateway_id" {
  description = "ID of the Customer Gateway"
  value       = aws_customer_gateway.onprem.id
}

output "vpn_connection_id" {
  description = "ID of the VPN connection"
  value       = aws_vpn_connection.main.id
}

output "tunnel_ips" {
  description = "AWS-side IP addresses for VPN tunnels (tunnel1 and tunnel2)"
  value = [
    aws_vpn_connection.main.tunnel1_address,
    aws_vpn_connection.main.tunnel2_address,
  ]
}

output "tunnel1_preshared_key" {
  description = "Pre-shared key for VPN tunnel 1 (sensitive)"
  value       = aws_vpn_connection.main.tunnel1_preshared_key
  sensitive   = true
}

output "tunnel2_preshared_key" {
  description = "Pre-shared key for VPN tunnel 2 (sensitive)"
  value       = aws_vpn_connection.main.tunnel2_preshared_key
  sensitive   = true
}
