variable "vpc_id" {
  description = "VPC ID for the ALB and security group"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB (minimum 2)"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

variable "linux_instance_id" {
  description = "Instance ID of the WildFly (Linux) target"
  type        = string
}

variable "windows_instance_id" {
  description = "Instance ID of the IIS (Windows) target"
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
