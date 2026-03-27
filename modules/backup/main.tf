#--------------------------------------------------------------
# Backup Module
# AWS Backup vault, plan, and selection for RDS and DynamoDB.
#--------------------------------------------------------------

resource "aws_backup_vault" "this" {
  count = var.enable_backup ? 1 : 0

  name = "${var.name_prefix}-vault"

  tags = {
    Name = "${var.name_prefix}-backup-vault"
  }
}

resource "aws_backup_plan" "this" {
  count = var.enable_backup ? 1 : 0

  name = "${var.name_prefix}-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.this[0].name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_retention_days
    }
  }

  tags = {
    Name = "${var.name_prefix}-backup-plan"
  }
}

resource "aws_iam_role" "backup" {
  count = var.enable_backup ? 1 : 0

  name = "${var.name_prefix}-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_selection" "rds" {
  count = var.enable_backup && var.rds_instance_arn != "" ? 1 : 0

  name         = "${var.name_prefix}-rds"
  plan_id      = aws_backup_plan.this[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  resources = [var.rds_instance_arn]
}

resource "aws_backup_selection" "dynamodb" {
  count = var.enable_backup && length(var.dynamodb_table_arns) > 0 ? 1 : 0

  name         = "${var.name_prefix}-dynamodb"
  plan_id      = aws_backup_plan.this[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  resources = var.dynamodb_table_arns
}
