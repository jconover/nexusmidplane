output "instance_id" {
  description = "ID of the WildFly EC2 instance"
  value       = aws_instance.wildfly.id
}

output "private_ip" {
  description = "Private IP address of the WildFly instance"
  value       = aws_instance.wildfly.private_ip
}

output "security_group_id" {
  description = "ID of the WildFly instance security group"
  value       = aws_security_group.wildfly.id
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the instance"
  value       = aws_iam_role.wildfly.name
}
