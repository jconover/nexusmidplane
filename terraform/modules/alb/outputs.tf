output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Route 53 hosted zone ID for the ALB (for alias records)"
  value       = aws_lb.main.zone_id
}

output "java_target_group_arn" {
  description = "ARN of the WildFly target group"
  value       = aws_lb_target_group.java.arn
}

output "dotnet_target_group_arn" {
  description = "ARN of the IIS target group"
  value       = aws_lb_target_group.dotnet.arn
}
