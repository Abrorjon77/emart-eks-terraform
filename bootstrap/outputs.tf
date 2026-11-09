output "bucket_name" {
  value = aws_s3_bucket.state.bucket
}

output "region" {
  value = var.region
}

output "name_servers" {
  description = "Paste these 4 into GoDaddy: DNS -> Nameservers -> I'll use my own nameservers"
  value       = aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  value = aws_acm_certificate.main.arn
}
