output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  value       = aws_sns_topic.alerts.arn
}

output "linux_log_group_name" {
  description = "CloudWatch log group name for the WildFly instance"
  value       = aws_cloudwatch_log_group.linux.name
}

output "windows_log_group_name" {
  description = "CloudWatch log group name for the IIS instance"
  value       = aws_cloudwatch_log_group.windows.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
