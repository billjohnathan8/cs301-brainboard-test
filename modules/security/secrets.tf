#--------------------------------------------------------------
# Security Module - Secrets Management
# This file manages application secrets using AWS Secrets Manager
# and generates secure random passwords for sensitive credentials
#--------------------------------------------------------------

# Local variables for secret values
# Allows passing pre-existing secrets or generating new ones
locals {
  jwt_hmac_secret_value     = var.jwt_hmac_secret != "" ? var.jwt_hmac_secret : random_password.jwt_hmac_secret.result
  root_admin_password_value = var.root_admin_password != "" ? var.root_admin_password : random_password.root_admin_password.result
  db_password_value         = random_password.db_password.result
}

# Random password generators - create cryptographically secure passwords
# These are only generated if not explicitly provided via variables

resource "random_password" "jwt_hmac_secret" {
  length           = 48
  special          = true
  override_special = "!@#$%*-_=+?"
}

resource "random_password" "root_admin_password" {
  length           = 20
  special          = true
  override_special = "!@#$%*-_=+?"
}

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%*-_=+?" # @ is not allowed in RDS master passwords
}

# AWS Secrets Manager secrets - securely store application credentials
# recovery_window_in_days = 0 allows immediate deletion (use with caution in prod)

resource "aws_secretsmanager_secret" "jwt_hmac" {
  name                    = "/${var.project_name}/${var.environment}/jwt/hmac_secret"
  description             = "Shared JWT HMAC secret for user/client/transaction/log."
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-jwt-hmac"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_hmac" {
  secret_id     = aws_secretsmanager_secret.jwt_hmac.id
  secret_string = local.jwt_hmac_secret_value
}

resource "aws_secretsmanager_secret" "root_admin_password" {
  name                    = "/${var.project_name}/${var.environment}/user/root_admin_password"
  description             = "Initial root admin password for user service."
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-root-admin-password"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "root_admin_password" {
  secret_id     = aws_secretsmanager_secret.root_admin_password.id
  secret_string = local.root_admin_password_value
}

resource "aws_secretsmanager_secret" "db_username" {
  name                    = "/${var.project_name}/${var.environment}/db/username"
  description             = "PostgreSQL username shared by services."
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-username"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_username" {
  secret_id     = aws_secretsmanager_secret.db_username.id
  secret_string = var.db_username
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "/${var.project_name}/${var.environment}/db/password"
  description             = "PostgreSQL password shared by services."
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-password"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = local.db_password_value
}
