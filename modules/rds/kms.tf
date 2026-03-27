#--------------------------------------------------------------
# KMS Key for RDS Encryption
# Creates a customer-managed encryption key for enhanced security
# and compliance requirements. Enables automatic key rotation.
#--------------------------------------------------------------

resource "aws_kms_key" "rds" {
  description             = "Customer-managed KMS key for ${var.name_prefix} RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.name_prefix}-rds-key"
    Environment = var.environment
    Service     = "rds"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}
