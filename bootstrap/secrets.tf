# MySQL password in AWS Secrets Manager. Kept between cluster rebuilds;
# External Secrets Operator copies it into the cluster as "mysql-secret".
# The value comes from bootstrap/terraform.tfvars (gitignored). It is sent as a
# write-only argument, so Terraform never stores it in terraform.tfstate.

resource "aws_secretsmanager_secret" "mysql" {
  name        = "emart/mysql"
  description = "MySQL root password for the emart app"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id        = aws_secretsmanager_secret.mysql.id
  secret_string_wo = jsonencode({ password = var.mysql_password })
  # Terraform cannot see a write-only value change, so bump this number
  # whenever you change mysql_password in terraform.tfvars
  secret_string_wo_version = 1
}
