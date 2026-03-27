#--------------------------------------------------------------
# RDS Module - Outputs
#--------------------------------------------------------------

output "rds_endpoint" {
  description = "RDS endpoint address."
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS endpoint port."
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Database name."
  value       = var.db_name
}

output "db_jdbc_url" {
  description = "JDBC URL for client service."
  value       = local.db_jdbc_url
}

output "rds_instance_arn" {
  description = "RDS instance ARN."
  value       = aws_db_instance.postgres.arn
}

output "rds_instance_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.postgres.identifier
}

output "kms_key_id" {
  description = "KMS key ID used for RDS encryption."
  value       = aws_kms_key.rds.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for RDS encryption."
  value       = aws_kms_key.rds.arn
}
