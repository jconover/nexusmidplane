output "certificate_arn" {
  description = "ARN of the ACM certificate (empty if no zone_id provided)"
  value       = local.has_zone_id ? aws_acm_certificate_validation.main[0].certificate_arn : ""
}

output "certificate_domain" {
  description = "Primary domain of the certificate"
  value       = local.has_zone_id ? aws_acm_certificate.main[0].domain_name : var.domain_name
}
