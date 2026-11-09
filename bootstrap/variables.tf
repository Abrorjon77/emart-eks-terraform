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

variable "mysql_password" {
  description = "MySQL root password; set it in terraform.tfvars (gitignored), never in a .tf file"
  type        = string
  sensitive   = true
  ephemeral   = true # never written to plan or state files
}

variable "grafana_admin_password" {
  description = "Grafana admin password; set it in terraform.tfvars (gitignored)"
  type        = string
  sensitive   = true
  ephemeral   = true
}
