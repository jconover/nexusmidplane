# ACM module — requests a public TLS certificate.
# When a Route 53 zone_id is provided, DNS validation is automated.
# Without a zone_id, the certificate is created but must be validated manually
# (or via the AWS console) before it can be used by the ALB.

locals {
  name_prefix    = "${var.project_name}-${var.environment}"
  has_zone_id    = var.zone_id != ""
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
# Only created when a valid zone_id is provided
resource "aws_route53_record" "validation" {
  for_each = local.has_zone_id ? {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

# Wait for certificate validation to complete before outputting ARN
# Only created when Route 53 validation is active
resource "aws_acm_certificate_validation" "main" {
  count                   = local.has_zone_id ? 1 : 0
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
