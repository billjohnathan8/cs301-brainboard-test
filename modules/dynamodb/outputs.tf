#--------------------------------------------------------------
# DynamoDB Module - Outputs
#--------------------------------------------------------------

output "audit_logs_table_name" {
  description = "Audit logs DynamoDB table name."
  value       = var.enable_audit_table ? aws_dynamodb_table.audit_logs[0].name : ""
}

output "audit_logs_table_arn" {
  description = "Audit logs DynamoDB table ARN."
  value       = var.enable_audit_table ? aws_dynamodb_table.audit_logs[0].arn : ""
}

output "aml_reports_table_name" {
  description = "AML reports DynamoDB table name."
  value       = var.enable_aml_table ? aws_dynamodb_table.aml_reports[0].name : ""
}

output "aml_reports_table_arn" {
  description = "AML reports DynamoDB table ARN."
  value       = var.enable_aml_table ? aws_dynamodb_table.aml_reports[0].arn : ""
}
