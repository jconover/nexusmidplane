variable "domain_name" {
  description = "Primary domain name for the ACM certificate"
  type        = string
}

variable "zone_id" {
  description = "Route 53 hosted zone ID for DNS validation records"
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
