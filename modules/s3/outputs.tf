#--------------------------------------------------------------
# S3 Module - Outputs
#--------------------------------------------------------------

output "frontend_bucket_name" {
  description = "Frontend bucket name."
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_bucket_id" {
  description = "Frontend bucket ID."
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "Frontend bucket ARN."
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_bucket_regional_domain_name" {
  description = "Frontend bucket regional domain name."
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "frontend_website_endpoint" {
  description = "S3 static website hosting endpoint URL (only when public access is enabled)."
  value       = var.frontend_bucket_allow_public ? "http://${aws_s3_bucket_website_configuration.frontend[0].website_endpoint}" : null
}

output "verification_bucket_id" {
  description = "Verification documents bucket ID."
  value       = var.enable_verification_bucket ? aws_s3_bucket.verification[0].id : null
}

output "verification_bucket_arn" {
  description = "Verification documents bucket ARN."
  value       = var.enable_verification_bucket ? aws_s3_bucket.verification[0].arn : null
}

output "transaction_sftp_bucket_name" {
  description = "Transaction ingestion source bucket name (legacy 'sftp' naming)."
  value       = var.enable_transaction_sftp_bucket ? aws_s3_bucket.transaction_sftp[0].bucket : null
}

output "transaction_sftp_bucket_id" {
  description = "Transaction ingestion source bucket ID (legacy 'sftp' naming)."
  value       = var.enable_transaction_sftp_bucket ? aws_s3_bucket.transaction_sftp[0].id : null
}

output "transaction_sftp_bucket_arn" {
  description = "Transaction ingestion source bucket ARN (legacy 'sftp' naming)."
  value       = var.enable_transaction_sftp_bucket ? aws_s3_bucket.transaction_sftp[0].arn : null
}
