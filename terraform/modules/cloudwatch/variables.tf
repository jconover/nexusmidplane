variable "linux_instance_id" {
  description = "Instance ID of the WildFly (Linux) EC2 instance"
  type        = string
}

variable "windows_instance_id" {
  description = "Instance ID of the IIS (Windows) EC2 instance"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (leave empty to skip SNS subscription)"
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization percentage threshold for alarm"
  type        = number
  default     = 80
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}
