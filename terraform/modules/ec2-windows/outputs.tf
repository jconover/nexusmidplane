output "instance_id" {
  description = "ID of the IIS EC2 instance"
  value       = aws_instance.iis.id
}

output "private_ip" {
  description = "Private IP address of the IIS instance"
  value       = aws_instance.iis.private_ip
}

output "security_group_id" {
  description = "ID of the IIS instance security group"
  value       = aws_security_group.iis.id
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the instance"
  value       = aws_iam_role.iis.name
}
