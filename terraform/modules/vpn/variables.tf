variable "vpc_id" {
  description = "VPC ID to attach the Virtual Private Gateway to"
  type        = string
}

variable "onprem_public_ip" {
  description = "Public IP address of the on-premises VPN endpoint"
  type        = string
}

variable "onprem_cidr" {
  description = "CIDR block of the on-premises network (for static routes)"
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

variable "bgp_asn" {
  description = "BGP ASN for the Customer Gateway (use 65000 for static-only VPN)"
  type        = number
  default     = 65000
}
