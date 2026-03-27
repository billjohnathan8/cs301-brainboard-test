#--------------------------------------------------------------
# Backup Module - Outputs
#--------------------------------------------------------------

output "backup_vault_arn" {
  description = "AWS Backup vault ARN."
  value       = var.enable_backup ? aws_backup_vault.this[0].arn : null
}

output "backup_plan_id" {
  description = "AWS Backup plan ID."
  value       = var.enable_backup ? aws_backup_plan.this[0].id : null
}
