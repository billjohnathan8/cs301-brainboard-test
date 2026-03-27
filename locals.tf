#--------------------------------------------------------------
# Local Values
# Computed values and derived names used across the root configuration.
# Centralises naming conventions, bucket names, and conditional logic.
#--------------------------------------------------------------

locals {
  #--------------------------------------------------------------
  # Naming and Tagging
  #--------------------------------------------------------------
  name_prefix = lower(replace("${var.project_name}-${var.environment}", "_", "-"))

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.extra_tags
  )

  #--------------------------------------------------------------
  # Domain and URL Resolution
  #--------------------------------------------------------------
  use_custom_domain = trimspace(var.app_domain_name) != ""

  # External-certificate mode is explicit: both frontend and ALB cert ARNs
  # must be provided together.
  use_existing_acm_certificates = (
    trimspace(var.existing_frontend_certificate_arn) != "" &&
    trimspace(var.existing_alb_certificate_arn) != ""
  )

  # Route53 record ownership is opt-in and only relevant for custom domains.
  manage_route53_records = local.use_custom_domain && var.manage_route53_records

  # ACM creation is opt-in for custom domains when cert ARNs are not provided.
  create_acm_certificates = local.use_custom_domain && var.create_acm_certificates && !local.use_existing_acm_certificates

  alb_origin_domain_name = local.use_custom_domain ? "${var.alb_origin_subdomain}.${var.app_domain_name}" : null

  frontend_certificate_arn = local.use_custom_domain ? (
    local.use_existing_acm_certificates ? var.existing_frontend_certificate_arn : try(module.acm[0].frontend_certificate_arn, null)
  ) : null

  alb_certificate_arn = local.use_custom_domain ? (
    local.use_existing_acm_certificates ? var.existing_alb_certificate_arn : try(module.acm[0].alb_certificate_arn, null)
  ) : null

  crm_api_base_url = var.aml_crm_api_base_url != "" ? var.aml_crm_api_base_url : (
    local.use_custom_domain ? "https://${local.alb_origin_domain_name}" : "http://${module.alb.alb_dns_name}"
  )

  transaction_import_api_base_url = var.transaction_import_api_base_url != "" ? var.transaction_import_api_base_url : local.crm_api_base_url

  verification_frontend_base_url = trimspace(var.verification_frontend_base_url) != "" ? trimspace(var.verification_frontend_base_url) : (
    local.use_custom_domain ? "https://${var.app_domain_name}" : ""
  )

  #--------------------------------------------------------------
  # S3 Bucket Names
  #--------------------------------------------------------------
  frontend_bucket_name = var.frontend_bucket_name != "" ? lower(var.frontend_bucket_name) : lower("${local.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}")

  verification_bucket_name = var.verification_bucket_name != "" ? var.verification_bucket_name : "${local.name_prefix}-verification-${data.aws_caller_identity.current.account_id}"

  transaction_sftp_bucket_name = var.transaction_sftp_bucket_name != "" ? var.transaction_sftp_bucket_name : "${local.name_prefix}-transaction-sftp-${data.aws_caller_identity.current.account_id}"

  #--------------------------------------------------------------
  # Subnet Selection
  # Use dedicated DB subnets if provided, otherwise fall back to private subnets
  #--------------------------------------------------------------
  db_subnet_ids = length(var.db_subnet_cidrs) > 0 ? module.network.db_subnet_ids : module.network.private_subnet_ids

  ecs_subnet_ids = var.ecs_use_public_subnets ? module.network.public_subnet_ids : module.network.private_subnet_ids

  #--------------------------------------------------------------
  # Backup Targets
  # Collect DynamoDB table ARNs for AWS Backup (filter out nulls)
  #--------------------------------------------------------------
  dynamodb_backup_arns = compact([
    module.dynamodb.audit_logs_table_arn != null ? module.dynamodb.audit_logs_table_arn : "",
    module.dynamodb.aml_reports_table_arn != null ? module.dynamodb.aml_reports_table_arn : "",
  ])
}
