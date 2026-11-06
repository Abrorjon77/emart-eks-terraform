output "bucket_name" {
  value = aws_s3_bucket.state.bucket
}

output "region" {
  value = var.region
}
