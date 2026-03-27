#--------------------------------------------------------------
# RDS Module
# PostgreSQL RDS instance, subnet group, parameter group,
# KMS encryption, and automated backup configuration.
#--------------------------------------------------------------

locals {
  db_jdbc_url = "jdbc:postgresql://${aws_db_instance.postgres.address}:${var.db_port}/${var.db_name}"
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.name_prefix}-db-subnets"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${var.name_prefix}-postgres-params"
  family = var.db_parameter_group_family

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  tags = {
    Name = "${var.name_prefix}-postgres-params"
  }
}

resource "aws_db_instance" "postgres" {
  identifier                 = "${var.name_prefix}-postgres"
  engine                     = "postgres"
  engine_version             = var.db_engine_version != "" ? var.db_engine_version : null
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  max_allocated_storage      = var.db_max_allocated_storage
  storage_type               = "gp3"
  storage_encrypted          = true
  kms_key_id                 = aws_kms_key.rds.arn
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = var.db_password_value
  port                       = var.db_port
  parameter_group_name       = aws_db_parameter_group.postgres.name
  db_subnet_group_name       = aws_db_subnet_group.postgres.name
  vpc_security_group_ids     = [var.db_security_group_id]
  backup_retention_period    = var.db_backup_retention_days
  multi_az                   = var.db_multi_az
  skip_final_snapshot        = var.db_skip_final_snapshot
  final_snapshot_identifier  = var.db_skip_final_snapshot ? null : "${var.name_prefix}-postgres-final"
  deletion_protection        = var.db_deletion_protection
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  apply_immediately          = true

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? aws_kms_key.rds.arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  iam_database_authentication_enabled = var.iam_database_authentication_enabled
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/${var.environment}/db/host"
  type  = "String"
  value = aws_db_instance.postgres.address
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project_name}/${var.environment}/db/port"
  type  = "String"
  value = tostring(var.db_port)
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/${var.environment}/db/name"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "client_db_url" {
  name  = "/${var.project_name}/${var.environment}/db/client/url"
  type  = "String"
  value = local.db_jdbc_url
}
