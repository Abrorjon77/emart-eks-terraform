variable "region" {
  description = "AWS region for the state bucket"
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  default     = "vprofile-terraform-state-1"
}

variable "domain_name" {
  description = "Domain registered at GoDaddy; its DNS is hosted in Route 53"
  default     = "registan.xyz"
}
