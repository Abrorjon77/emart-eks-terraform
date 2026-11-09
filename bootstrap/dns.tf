# Route 53 hosted zone and ACM certificate for the app's domain.
# They live here, not in the main config, so they survive cluster rebuilds:
# a new zone would get new nameservers and you would have to update GoDaddy again.

resource "aws_route53_zone" "main" {
  name = var.domain_name

  lifecycle {
    prevent_destroy = true
  }
}

# Covers the bare domain and every subdomain (www, api, ...)
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM checks these records to prove you own the domain. Both names share one
# record, hence allow_overwrite. Validation completes on its own once GoDaddy
# points the domain at this zone's nameservers.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 300
  allow_overwrite = true
}
