# ACM module — requests and DNS-validates a public TLS certificate.
# DNS validation is automated via Route 53; validation typically completes within 5 minutes.

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  # Include www subdomain as a SAN
  subject_alternative_names = [
    "www.${var.domain_name}",
  ]

  tags = {
    Name = "${local.name_prefix}-cert"
  }

  lifecycle {
    # Create new cert before destroying old one to avoid downtime during renewal
    create_before_destroy = true
  }
}

# Route 53 DNS validation records (one per domain/SAN)
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

# Wait for certificate validation to complete before outputting ARN
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
