#--------------------------------------------------------------
# SQS Module - Outputs
#--------------------------------------------------------------

output "audit_queue_arn" {
  description = "Audit SQS queue ARN."
  value       = var.enable_audit_pipeline ? aws_sqs_queue.audit[0].arn : null
}

output "audit_queue_url" {
  description = "Audit SQS queue URL."
  value       = var.enable_audit_pipeline ? aws_sqs_queue.audit[0].url : null
}

output "audit_dlq_arn" {
  description = "Audit SQS DLQ ARN."
  value       = var.enable_audit_pipeline ? aws_sqs_queue.audit_dlq[0].arn : null
}

output "aml_queue_arn" {
  description = "AML SQS queue ARN."
  value       = var.enable_aml_pipeline ? aws_sqs_queue.aml[0].arn : null
}

output "aml_queue_url" {
  description = "AML SQS queue URL."
  value       = var.enable_aml_pipeline ? aws_sqs_queue.aml[0].url : null
}

output "aml_dlq_arn" {
  description = "AML SQS DLQ ARN."
  value       = var.enable_aml_pipeline ? aws_sqs_queue.aml_dlq[0].arn : null
}
