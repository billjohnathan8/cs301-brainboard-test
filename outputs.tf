#--------------------------------------------------------------
# CS301 Group 2 Team 3 Project - Terraform Outputs
#
# Exports key resource identifiers and endpoints for use in
# CI/CD pipelines, application configuration, and external DNS setup.
#--------------------------------------------------------------

#--------------------------------------------------------------
# Network Outputs
#--------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.network.private_subnet_ids
}

#--------------------------------------------------------------
# Compute Outputs
#--------------------------------------------------------------
output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.ecs_cluster_name
}

output "ecr_repository_url" {
  description = "Compatibility output for the user service ECR repository URL."
  value       = module.ecr.repository_url
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service name."
  value       = module.ecr.repository_urls
}

output "ecr_repository_names" {
  description = "ECR repository names keyed by service name."
  value       = module.ecr.repository_names
}

#--------------------------------------------------------------
# Edge and Delivery Outputs
#--------------------------------------------------------------
output "alb_dns_name" {
  description = "ALB DNS name."
  value       = module.alb.alb_dns_name
}

output "log_api_invoke_url" {
  description = "API Gateway invoke URL for log Lambda routes."
  value       = var.enable_log_lambda ? module.apigateway[0].log_api_base_url : null
}

#--------------------------------------------------------------
# Database Outputs
#--------------------------------------------------------------
output "rds_endpoint" {
  description = "RDS endpoint hostname."
  value       = module.rds.rds_endpoint
}

output "rds_port" {
  description = "RDS endpoint port."
  value       = module.rds.rds_port
}

output "database_name" {
  description = "Application database name."
  value       = module.rds.database_name
}

#--------------------------------------------------------------
# CloudFront Outputs
#--------------------------------------------------------------
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = try(module.cloudfront[0].cloudfront_distribution_id, null)
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = try(module.cloudfront[0].cloudfront_distribution_domain_name, null)
}

output "app_url" {
  description = "Primary app URL (CloudFront when enabled, ALB otherwise)."
  value       = try(module.cloudfront[0].app_url, "http://${module.alb.alb_dns_name}")
}

output "custom_domain_mode" {
  description = "How custom-domain certificates are sourced."
  value = local.use_custom_domain ? (
    local.use_existing_acm_certificates ? "external_acm_certificates" : (
      local.create_acm_certificates ? "terraform_acm_certificates" : "invalid_custom_domain_contract"
    )
  ) : "disabled"
}

output "terraform_manages_route53_records" {
  description = "Whether Terraform is configured to manage Route53 records for this deployment."
  value       = local.manage_route53_records
}

#--------------------------------------------------------------
# External DNS Outputs
# Values to create CNAME / A records in an externally-managed DNS zone
#--------------------------------------------------------------
output "external_dns_frontend_name" {
  description = "DNS name to create externally for app traffic."
  value       = var.app_domain_name != "" ? var.app_domain_name : null
}

output "external_dns_frontend_target" {
  description = "CloudFront domain to target from external DNS."
  value       = try(module.cloudfront[0].cloudfront_distribution_domain_name, null)
}

output "external_dns_alb_origin_name" {
  description = "DNS name to create externally for CloudFront-to-ALB origin."
  value       = local.alb_origin_domain_name
}

output "external_dns_alb_origin_target" {
  description = "ALB DNS name to target from external DNS."
  value       = module.alb.alb_dns_name
}

output "acm_us_certificate_validation_records" {
  description = "DNS records to create for validating the CloudFront ACM certificate (when Terraform creates certs)."
  value       = local.create_acm_certificates ? module.acm[0].us_certificate_validation_records : []
}

output "acm_ap_certificate_validation_records" {
  description = "DNS records to create for validating the regional ALB ACM certificate (when Terraform creates certs)."
  value       = local.create_acm_certificates ? module.acm[0].ap_certificate_validation_records : []
}

output "frontend_bucket_name" {
  description = "Frontend S3 bucket name."
  value       = module.s3.frontend_bucket_name
}

output "frontend_website_url" {
  description = "S3 static website hosting URL (when CloudFront is disabled and public access is enabled)."
  value       = module.s3.frontend_website_endpoint
}

output "transaction_sftp_bucket_name" {
  description = "Transaction ingestion source S3 bucket name (legacy 'sftp' naming)."
  value       = module.s3.transaction_sftp_bucket_name
}

#--------------------------------------------------------------
# Secrets Manager Outputs
#--------------------------------------------------------------
output "jwt_secret_arn" {
  description = "Secrets Manager ARN for JWT HMAC secret."
  value       = module.security.jwt_hmac_secret_arn
}

output "root_admin_password_secret_arn" {
  description = "Secrets Manager ARN for root admin password."
  value       = module.security.root_admin_password_secret_arn
}

output "db_username_secret_arn" {
  description = "Secrets Manager ARN for database username."
  value       = module.security.db_username_secret_arn
}

output "db_password_secret_arn" {
  description = "Secrets Manager ARN for database password."
  value       = module.security.db_password_secret_arn
}

#--------------------------------------------------------------
# Lambda Outputs
#--------------------------------------------------------------
output "log_lambda_name" {
  description = "Log service Lambda function name."
  value       = module.lambda.log_lambda_name
}

output "aml_lambda_name" {
  description = "AML Lambda function name."
  value       = module.lambda.aml_lambda_name
}

output "sftp_transaction_collector_name" {
  description = "Scheduled sftp-transaction-collector Lambda function name."
  value       = module.lambda.sftp_transaction_collector_name
}

#--------------------------------------------------------------
# IAM Outputs
#--------------------------------------------------------------
output "ecs_task_role_arns" {
  description = "Per-service ECS task role ARNs."
  value       = module.security.ecs_task_role_arns
}

output "terraform_backend_policy_arn" {
  description = "IAM policy ARN for Terraform backend access (when enabled)."
  value       = module.security.terraform_backend_policy_arn
}

#--------------------------------------------------------------
# Network: Database Subnets
#--------------------------------------------------------------
output "db_subnet_ids" {
  description = "Database subnet IDs (dedicated or private fallback)."
  value       = local.db_subnet_ids
}

#--------------------------------------------------------------
# Cognito Outputs
#--------------------------------------------------------------
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID."
  value       = var.enable_cognito ? module.cognito[0].user_pool_id : null
}

output "cognito_app_client_id" {
  description = "Cognito App Client ID."
  value       = var.enable_cognito ? module.cognito[0].app_client_id : null
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint."
  value       = var.enable_cognito ? module.cognito[0].user_pool_endpoint : null
}

output "cognito_issuer_url" {
  description = "Cognito issuer URL used for JWT verification."
  value       = var.enable_cognito ? module.cognito[0].issuer_url : null
}

output "cognito_jwks_url" {
  description = "Cognito JWKS URL used for JWT verification."
  value       = var.enable_cognito ? module.cognito[0].jwks_url : null
}

#--------------------------------------------------------------
# Messaging Outputs (SQS / SNS)
#--------------------------------------------------------------
output "audit_queue_url" {
  description = "Audit SQS queue URL."
  value       = module.sqs.audit_queue_url
}

output "aml_queue_url" {
  description = "AML SQS queue URL."
  value       = module.sqs.aml_queue_url
}

output "verification_topic_arn" {
  description = "Verification SNS topic ARN."
  value       = module.sns.verification_topic_arn
}

output "alarm_notification_topic_arn" {
  description = "Effective SNS topic ARN used by CloudWatch alarm actions."
  value       = trimspace(var.alarm_notification_topic_arn) != "" ? trimspace(var.alarm_notification_topic_arn) : module.sns.alarm_topic_arn
}

#--------------------------------------------------------------
# SES Outputs
#--------------------------------------------------------------
output "ses_domain_identity_arn" {
  description = "SES domain identity ARN."
  value       = module.ses.domain_identity_arn
}

output "ses_domain_verification_token" {
  description = "TXT record value for SES domain verification. Create: _amazonses.{domain} TXT {token}"
  value       = module.ses.domain_verification_token
}

output "ses_dkim_tokens" {
  description = "DKIM CNAME tokens. Create 3 CNAMEs: {token}._domainkey.{domain} -> {token}.dkim.amazonses.com"
  value       = module.ses.dkim_tokens
}

output "ses_mail_from_domain" {
  description = "Custom MAIL FROM domain. Create MX + SPF TXT records (see docs)."
  value       = module.ses.mail_from_domain
}

#--------------------------------------------------------------
# DynamoDB Outputs
#--------------------------------------------------------------
output "audit_logs_table_name" {
  description = "Audit logs DynamoDB table name."
  value       = module.dynamodb.audit_logs_table_name
}

output "aml_reports_table_name" {
  description = "AML reports DynamoDB table name."
  value       = module.dynamodb.aml_reports_table_name
}

# --- Pipeline Lambdas ---

output "audit_consumer_lambda_name" {
  description = "Audit consumer Lambda function name."
  value       = module.lambda.audit_consumer_lambda_name
}

output "aml_consumer_lambda_name" {
  description = "AML consumer Lambda function name."
  value       = module.lambda.aml_consumer_lambda_name
}

output "verification_lambda_name" {
  description = "Verification Lambda function name."
  value       = module.lambda.verification_lambda_name
}

# --- Observability ---

output "cloudtrail_arn" {
  description = "CloudTrail ARN."
  value       = module.observability.cloudtrail_arn
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name for ECS and ALB monitoring."
  value       = module.observability.dashboard_name
}

# --- Backup ---

output "backup_vault_arn" {
  description = "AWS Backup vault ARN."
  value       = module.backup.backup_vault_arn
}

# --- CodeDeploy ---

output "codedeploy_ecs_application_name" {
  description = "CodeDeploy ECS application name."
  value       = module.codedeploy.ecs_application_name
}

output "codedeploy_lambda_application_name" {
  description = "CodeDeploy Lambda application name."
  value       = module.codedeploy.lambda_application_name
}

output "codedeploy_ecs_deployment_group_names" {
  description = "CodeDeploy ECS deployment group names keyed by service."
  value       = module.codedeploy.ecs_deployment_group_names
}

output "codedeploy_lambda_deployment_group_names" {
  description = "CodeDeploy Lambda deployment group names keyed by logical lambda service."
  value       = module.codedeploy.lambda_deployment_group_names
}
