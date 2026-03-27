#--------------------------------------------------------------
# Lambda Module - Outputs
#--------------------------------------------------------------

output "log_lambda_name" {
  description = "Log lambda function name."
  value       = var.enable_log_lambda ? aws_lambda_function.log[0].function_name : ""
}

output "log_lambda_invoke_arn" {
  description = "Log lambda invoke ARN."
  value       = var.enable_log_lambda ? aws_lambda_function.log[0].invoke_arn : ""
}

output "aml_lambda_name" {
  description = "AML lambda function name."
  value       = var.enable_aml_lambda ? aws_lambda_function.aml[0].function_name : ""
}

output "sftp_transaction_collector_name" {
  description = "Transaction ingestion Lambda function name."
  value       = var.enable_sftp_transaction_collector ? aws_lambda_function.sftp_transaction_collector[0].function_name : ""
}

output "audit_consumer_lambda_name" {
  description = "Audit consumer Lambda function name."
  value       = var.enable_audit_consumer ? aws_lambda_function.audit_consumer[0].function_name : ""
}

output "aml_consumer_lambda_name" {
  description = "AML consumer Lambda function name."
  value       = var.enable_aml_consumer ? aws_lambda_function.aml_consumer[0].function_name : ""
}

output "verification_lambda_name" {
  description = "Verification Lambda function name."
  value       = var.enable_verification_lambda ? aws_lambda_function.verification[0].function_name : ""
}

output "log_lambda_alias_name" {
  description = "Deployment alias name for log Lambda."
  value       = var.enable_log_lambda ? aws_lambda_alias.log_live[0].name : ""
}

output "aml_lambda_alias_name" {
  description = "Deployment alias name for AML Lambda."
  value       = var.enable_aml_lambda ? aws_lambda_alias.aml_live[0].name : ""
}

output "sftp_transaction_collector_alias_name" {
  description = "Deployment alias name for sftp-transaction-collector Lambda."
  value       = var.enable_sftp_transaction_collector ? aws_lambda_alias.sftp_transaction_collector_live[0].name : ""
}

output "verification_lambda_alias_name" {
  description = "Deployment alias name for verification Lambda."
  value       = var.enable_verification_lambda ? aws_lambda_alias.verification_live[0].name : ""
}
