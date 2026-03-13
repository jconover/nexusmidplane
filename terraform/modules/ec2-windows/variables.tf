variable "instance_type" {
  description = "EC2 instance type for the IIS host"
  type        = string
  default     = "t3.small"
}

variable "subnet_id" {
  description = "Private subnet ID where the instance will be launched"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for security group association"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block (used to restrict WinRM and RDP access)"
  type        = string
}

variable "key_pair_name" {
  description = "EC2 key pair name for RDP password decryption (leave empty to disable)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
}
