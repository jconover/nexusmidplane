output "certificate_arn" {
  description = "ARN of the ACM certificate (validated if zone_id was provided)"
  value       = local.has_zone_id ? aws_acm_certificate_validation.main[0].certificate_arn : aws_acm_certificate.main.arn
}

output "certificate_domain" {
  description = "Primary domain of the certificate"
  value       = aws_acm_certificate.main.domain_name
}
