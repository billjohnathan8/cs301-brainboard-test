#--------------------------------------------------------------
# CS301 Group 2 Team 3 Project - Root Variables
#
# All input variables for the root Terraform configuration.
# Sensitive values should be supplied via terraform.tfvars or
# environment variables (not committed to version control).
#--------------------------------------------------------------

#--------------------------------------------------------------
# General Settings
#--------------------------------------------------------------
variable "project_name" {
  description = "Project name used as a naming prefix for AWS resources."
  type        = string
  default     = "scroogebank-crm"
}

variable "environment" {
  description = "Environment name (for example: dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = trimspace(var.environment) != ""
    error_message = "environment must not be empty."
  }
}

variable "aws_region" {
  description = "Primary AWS region for this deployment."
  type        = string
  default     = "ap-southeast-1"
}

variable "extra_tags" {
  description = "Additional tags merged into all resources."
  type        = map(string)
  default     = {}
}

#--------------------------------------------------------------
# Network Configuration
#--------------------------------------------------------------
variable "az_count" {
  description = "How many Availability Zones to use."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "The az_count value must be at least 2 for high availability."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (must match az_count)."
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private app/data subnets (must match az_count)."
  type        = list(string)
  default     = ["10.42.10.0/24", "10.42.11.0/24"]
}

#--------------------------------------------------------------
# Container Registry
#--------------------------------------------------------------
variable "ecr_repository_name" {
  description = "ECR repository name. Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "ecr_repository_names" {
  description = "Optional explicit ECR repository names keyed by service (user, client, transaction)."
  type        = map(string)
  default     = {}
}

#--------------------------------------------------------------
# ECS Service Image Tags
#--------------------------------------------------------------
variable "user_image_tag" {
  description = "ECR image tag for the user service container."
  type        = string
  default     = "user-dev-001"
}

variable "client_image_tag" {
  description = "ECR image tag for the client service container."
  type        = string
  default     = "client-dev-001"
}

variable "transaction_image_tag" {
  description = "ECR image tag for the transaction service container."
  type        = string
  default     = "transaction-dev-001"
}

#--------------------------------------------------------------
# ECS Service Task Counts
#--------------------------------------------------------------
variable "enable_stateful_service_scale_out" {
  description = "Allow user and transaction services to scale beyond one task. Enable only after Phase B persistence is fully deployed and verified."
  type        = bool
  default     = false
}

variable "user_desired_count" {
  description = "Desired ECS task count for user service. Must remain 1 unless enable_stateful_service_scale_out is true."
  type        = number
  default     = 1
}

variable "client_desired_count" {
  description = "Desired ECS task count for client service."
  type        = number
  default     = 2
}

variable "transaction_desired_count" {
  description = "Desired ECS task count for transaction service. Must remain 1 unless enable_stateful_service_scale_out is true."
  type        = number
  default     = 1
}

#--------------------------------------------------------------
# ECS Fargate Resource Allocation and Autoscaling
#--------------------------------------------------------------
variable "ecs_task_cpu" {
  description = "Fargate task CPU units (applied to each backend service)."
  type        = number
  default     = 512
}

variable "ecs_task_memory" {
  description = "Fargate task memory (MiB) (applied to each backend service)."
  type        = number
  default     = 1024
}

variable "ecs_min_capacity" {
  description = "Minimum task count for ECS autoscaling (applies to stateless services only)."
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum task count for ECS autoscaling (applies to stateless services only)."
  type        = number
  default     = 4
}

variable "ecs_target_cpu_utilization" {
  description = "Target average CPU utilization percent for ECS autoscaling."
  type        = number
  default     = 70
}

variable "ecs_target_memory_utilization" {
  description = "Target average memory utilization percent for ECS autoscaling."
  type        = number
  default     = 75
}

variable "ecs_use_public_subnets" {
  description = "Run ECS services in public subnets instead of private subnets. Useful for low-cost lab deployments when NAT Gateways are disabled."
  type        = bool
  default     = false
}

variable "ecs_assign_public_ip" {
  description = "Assign public IP addresses to ECS tasks. Must be true when ecs_use_public_subnets is true."
  type        = bool
  default     = false
}

variable "enable_ecs_container_insights" {
  description = "Enable ECS Container Insights. Disable for lower CloudWatch cost in budget-constrained environments."
  type        = bool
  default     = false
}

#--------------------------------------------------------------
# Database (RDS PostgreSQL) Configuration
#--------------------------------------------------------------
variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "crm"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "crm_app"
}

variable "db_port" {
  description = "PostgreSQL port."
  type        = number
  default     = 5432
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version. Leave empty to use AWS default."
  type        = string
  default     = ""
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS max autoscaling storage in GiB."
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ for the RDS instance. Must be true for prod."
  type        = bool
  default     = true
}

variable "db_backup_retention_days" {
  description = "RDS automated backup retention period in days (minimum 7 for prod)."
  type        = number
  default     = 7
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying the DB instance. Safer default is false."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on the DB instance. Safer default is true."
  type        = bool
  default     = true
}

variable "rds_performance_insights_enabled" {
  description = "Enable RDS Performance Insights. Disable for lower cost during first-time budget-sensitive bring-up."
  type        = bool
  default     = false
}

#--------------------------------------------------------------
# Secrets and Credentials
# Dev/staging may leave values empty for auto-generation via Secrets Manager.
# Prod must pass explicit strong values (validated below).
#--------------------------------------------------------------
variable "jwt_hmac_secret" {
  description = "JWT HMAC secret. For prod, provide a strong explicit value (>=32 chars) via TF_VAR_jwt_hmac_secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "root_admin_email" {
  description = "Initial root admin email for the user service."
  type        = string
  default     = "admin@crm.local"
}

variable "root_admin_password" {
  description = "Initial root admin password. For prod, provide a strong explicit value via TF_VAR_root_admin_password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "transaction_mock_sftp_root" {
  description = "MOCK_SFTP_ROOT for transaction service."
  type        = string
  default     = "./mock-sftp"
}

variable "transaction_sftp_bucket_name" {
  description = "S3 bucket name used as transaction ingestion source. Name retains legacy 'sftp' terminology for compatibility. Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "transaction_import_s3_endpoint" {
  description = "Optional S3 endpoint override used by transaction service when importing from S3."
  type        = string
  default     = ""
}

variable "transaction_import_s3_path_style_access_enabled" {
  description = "Enable S3 path-style access for transaction service S3 imports."
  type        = bool
  default     = false
}

#--------------------------------------------------------------
# Lambda Functions Configuration
#--------------------------------------------------------------
variable "enable_log_lambda" {
  description = "Create the log service Lambda and its API Gateway integration."
  type        = bool
  default     = false
}

variable "log_lambda_zip_path" {
  description = "Path to the packaged log Lambda zip artifact."
  type        = string
  default     = "../../services/backend/log/log-lambda.zip"
}

variable "log_lambda_memory_size" {
  description = "Memory size (MB) for log Lambda."
  type        = number
  default     = 512
}

variable "log_lambda_timeout_seconds" {
  description = "Timeout (seconds) for log Lambda."
  type        = number
  default     = 30
}

#--------------------------------------------------------------
# AML / SFTP Ingestion Configuration
#--------------------------------------------------------------
variable "enable_aml_lambda" {
  description = "Create the scheduled AML ingestion Lambda and EventBridge schedule."
  type        = bool
  default     = false
}

variable "enable_sftp_transaction_collector" {
  description = "Create the scheduled sftp-transaction-collector Lambda and EventBridge schedule."
  type        = bool
  default     = false
}

variable "sftp_transaction_collector_zip_path" {
  description = "Path to the packaged sftp-transaction-collector Lambda zip artifact."
  type        = string
  default     = "../../services/backend/sftp-transaction-collector/sftp-transaction-collector.zip"
}

variable "sftp_transaction_collector_memory_size" {
  description = "Memory size (MB) for sftp-transaction-collector Lambda."
  type        = number
  default     = 512
}

variable "sftp_transaction_collector_timeout_seconds" {
  description = "Timeout (seconds) for sftp-transaction-collector Lambda."
  type        = number
  default     = 60
}

variable "sftp_transaction_collector_schedule_expression" {
  description = "EventBridge schedule expression for sftp-transaction-collector Lambda."
  type        = string
  default     = "rate(1 hour)"
}

variable "transaction_sftp_remote_prefix" {
  description = "S3 object prefix scanned by sftp-transaction-collector Lambda (legacy 'sftp' naming)."
  type        = string
  default     = "incoming/"
}

variable "transaction_import_api_base_url" {
  description = "Override base URL for transaction import API. Leave empty to use ALB-derived CRM base URL."
  type        = string
  default     = ""
}

variable "transaction_import_api_path" {
  description = "HTTP path called by sftp-transaction-collector Lambda to trigger transaction import."
  type        = string
  default     = "/api/transactions/import"
}

variable "aml_lambda_zip_path" {
  description = "Path to the packaged AML Lambda zip artifact."
  type        = string
  default     = "../../services/backend/aml/aml-lambda.zip"
}

variable "aml_lambda_memory_size" {
  description = "Memory size (MB) for AML Lambda."
  type        = number
  default     = 1024
}

variable "aml_lambda_timeout_seconds" {
  description = "Timeout (seconds) for AML Lambda."
  type        = number
  default     = 120
}

variable "aml_schedule_expression" {
  description = "EventBridge schedule expression for AML Lambda."
  type        = string
  default     = "cron(0 0 1 * ? *)"
}

variable "aml_sftp_host" {
  description = "SFTP host consumed by AML Lambda."
  type        = string
  default     = ""
}

variable "aml_sftp_port" {
  description = "SFTP port consumed by AML Lambda."
  type        = number
  default     = 22
}

variable "aml_sftp_user" {
  description = "SFTP user consumed by AML Lambda."
  type        = string
  default     = ""
}

variable "aml_sftp_key_secret_arn" {
  description = "Optional Secrets Manager ARN for AML SFTP private key. Not used for S3-based mock SFTP data."
  type        = string
  default     = ""
}

variable "aml_sftp_remote_path" {
  description = "Remote SFTP CSV path for AML Lambda."
  type        = string
  default     = "/transactions/latest.csv"
}

variable "aml_entity_id" {
  description = "Entity ID consumed by AML Lambda."
  type        = string
  default     = "sg"
}

variable "aml_crm_api_base_url" {
  description = "Override CRM API base URL for AML Lambda. Leave empty to use ALB URL."
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# S3 and CloudFront Configuration
#--------------------------------------------------------------
variable "frontend_bucket_name" {
  description = "S3 bucket name for frontend assets. Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "frontend_bucket_force_destroy" {
  description = "Allow Terraform destroy to delete non-empty frontend bucket."
  type        = bool
  default     = false
}

variable "frontend_bucket_allow_public" {
  description = "Disable S3 public access block on the frontend bucket. Required when using S3 static website hosting without CloudFront."
  type        = bool
  default     = false
}

variable "cloudfront_price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition = contains(
      ["PriceClass_All", "PriceClass_200", "PriceClass_100"],
      var.cloudfront_price_class
    )
    error_message = "The cloudfront_price_class value must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

#--------------------------------------------------------------
# Domain, DNS, and TLS Configuration
#--------------------------------------------------------------
variable "app_domain_name" {
  description = "Custom domain for the app (optional)."
  type        = string
  default     = ""
}

variable "route53_hosted_zone_id" {
  description = "School-provided Route53 hosted zone ID. Used to create DNS records (A records) for services. Does NOT manage the hosted zone itself."
  type        = string
  default     = ""
}

variable "manage_route53_records" {
  description = "Whether Terraform should manage Route53 records in the provided hosted zone. Keep false to treat school Route53 as externally managed."
  type        = bool
  default     = false
}

variable "manage_acm_dns_validation_records" {
  description = "Whether Terraform should create ACM DNS validation records in Route53. Keep false when DNS validation records are created manually by the school/domain owner."
  type        = bool
  default     = false
}

variable "create_acm_certificates" {
  description = "Whether Terraform should request ACM certificates for custom domains. When false, provide existing cert ARNs."
  type        = bool
  default     = false
}

variable "existing_frontend_certificate_arn" {
  description = "Pre-existing ACM certificate ARN in us-east-1 for CloudFront. Used when create_acm_certificates=false."
  type        = string
  default     = ""
}

variable "existing_alb_certificate_arn" {
  description = "Pre-existing ACM certificate ARN in the primary AWS region for ALB. Used when create_acm_certificates=false."
  type        = string
  default     = ""
}

variable "acm_wait_for_validation" {
  description = "Wait for ACM certificates to reach ISSUED status in Terraform apply. Keep true for one-pass bring-up."
  type        = bool
  default     = true
}

variable "alb_origin_subdomain" {
  description = "Subdomain used as the CloudFront-to-ALB origin host when custom domain is enabled."
  type        = string
  default     = "api"
}

variable "enforce_strict_prod_guardrails" {
  description = "Enforce strict production high-availability guardrails (Multi-AZ NAT/RDS and stricter RDS destruction settings). Set false for budget-first production-account bring-up."
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# WAF and Logging
#--------------------------------------------------------------
variable "enable_waf" {
  description = "Attach an AWS WAFv2 Web ACL to CloudFront."
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days for ECS, Lambda, and API Gateway logs."
  type        = number
  default     = 30
}

#--------------------------------------------------------------
# Learner Lab / Restricted IAM Environments
#--------------------------------------------------------------
variable "lab_role_arn" {
  description = "Pre-existing IAM role ARN to use instead of creating new roles (e.g. LabRole in Learner Lab). When set, all aws_iam_role creation is skipped and this ARN is used for all role outputs."
  type        = string
  default     = ""
}

variable "lab_role_name" {
  description = "Pre-existing IAM role name to use in restricted environments (for example, LabRole in Learner Lab). Used only when lab_role_arn is empty."
  type        = string
  default     = ""
}

variable "enable_cloudfront" {
  description = "Create the CloudFront distribution. Disable when LabRole blocks cloudfront:CreateDistribution."
  type        = bool
  default     = true
}

variable "enable_cloudfront_oac" {
  description = "Create CloudFront Origin Access Control for the S3 frontend bucket. Disable when LabRole blocks cloudfront:CreateOriginAccessControl."
  type        = bool
  default     = true
}

variable "enable_service_discovery" {
  description = "Enable AWS Cloud Map private DNS namespace and service discovery for ECS inter-service communication. Disable when LabRole blocks servicediscovery:CreatePrivateDnsNamespace."
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# Terraform Backend Access Policy
#--------------------------------------------------------------
variable "create_backend_iam_policy" {
  description = "Whether to create an IAM policy for Terraform backend (S3 state + DynamoDB lock table) access."
  type        = bool
  default     = false
}

variable "backend_state_bucket_name" {
  description = "S3 bucket name used for Terraform state backend access policy."
  type        = string
  default     = ""
}

variable "backend_lock_table_name" {
  description = "DynamoDB table name used for Terraform lock backend access policy."
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Network: Database Subnets and VPC Options
#--------------------------------------------------------------
variable "db_subnet_cidrs" {
  description = "CIDR blocks for dedicated database subnets. If empty, RDS uses private subnets."
  type        = list(string)
  default     = []
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch."
  type        = bool
  default     = true
}

variable "enable_multi_az_nat" {
  description = "Enable NAT Gateway in each AZ for high availability. Increases cost (one NAT Gateway per AZ). Must be true for prod."
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway resources for private subnet egress. Disable for low-cost lab deployments that place ECS tasks in public subnets."
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# Cognito (User Authentication)
#--------------------------------------------------------------
variable "enable_cognito" {
  description = "Create Cognito User Pool and App Client."
  type        = bool
  default     = true
}

variable "cognito_domain_prefix" {
  description = "Cognito hosted UI domain prefix. Leave empty to skip."
  type        = string
  default     = ""
}

variable "cognito_callback_urls" {
  description = "OAuth callback URLs for Cognito app client."
  type        = list(string)
  default     = []
}

variable "cognito_logout_urls" {
  description = "OAuth logout URLs for Cognito app client."
  type        = list(string)
  default     = []
}

variable "cognito_mfa_configuration" {
  description = "Cognito MFA configuration for the user pool. Allowed values: OFF, OPTIONAL, ON."
  type        = string
  default     = "OFF"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], upper(trimspace(var.cognito_mfa_configuration)))
    error_message = "cognito_mfa_configuration must be one of: OFF, OPTIONAL, ON."
  }
}

variable "auth_mode" {
  description = "Runtime auth mode for backend services. Supported values: local, hybrid, cognito."
  type        = string
  default     = "hybrid"

  validation {
    condition     = contains(["local", "hybrid", "cognito"], lower(trimspace(var.auth_mode)))
    error_message = "auth_mode must be one of: local, hybrid, cognito."
  }
}

variable "cognito_issuer_url" {
  description = "Optional Cognito issuer URL override. Leave empty to derive from the Cognito module output."
  type        = string
  default     = ""
}

variable "cognito_jwks_url" {
  description = "Optional Cognito JWKS URL override. Leave empty to derive from the Cognito module output."
  type        = string
  default     = ""
}

variable "cognito_audience" {
  description = "Optional Cognito audience/client ID override. Leave empty to derive from the Cognito app client ID."
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Messaging Pipelines (Audit, AML, Verification)
#--------------------------------------------------------------
variable "enable_audit_pipeline" {
  description = "Create audit SQS queue, consumer Lambda, and DynamoDB table for the async audit pipeline."
  type        = bool
  default     = false
}

variable "enable_aml_pipeline" {
  description = "Create AML SQS queue, consumer Lambda, and DynamoDB table for the async AML pipeline."
  type        = bool
  default     = false
}

variable "enable_verification_pipeline" {
  description = "Create verification Lambda, SNS topic, SES identity, and S3 bucket."
  type        = bool
  default     = false
}

variable "audit_consumer_zip_path" {
  description = "Path to audit consumer Lambda zip artifact."
  type        = string
  default     = "../../services/backend/audit-consumer/audit-consumer-lambda.zip"
}

variable "aml_consumer_zip_path" {
  description = "Path to AML consumer Lambda zip artifact."
  type        = string
  default     = "../../services/backend/aml-consumer/aml-consumer-lambda.zip"
}

variable "verification_zip_path" {
  description = "Path to verification Lambda zip."
  type        = string
  default     = "../../services/backend/verification/verification-lambda.zip"
}

#--------------------------------------------------------------
# SES (Email Service)
#--------------------------------------------------------------
variable "ses_sender_email" {
  description = "SES verified sender email for verification notifications."
  type        = string
  default     = ""
}

variable "verification_frontend_base_url" {
  description = "Frontend base URL used to build public verification links in emails."
  type        = string
  default     = ""

  validation {
    condition = trimspace(var.verification_frontend_base_url) == "" || can(
      regex("^https?://", trimspace(var.verification_frontend_base_url))
    )
    error_message = "verification_frontend_base_url must start with http:// or https:// when set."
  }
}

variable "ses_notification_email" {
  description = "Email endpoint for SNS verification subscription."
  type        = string
  default     = ""
}

variable "ses_domain" {
  description = "Domain for SES domain identity with DKIM/SPF. Leave empty to use simple email identity."
  type        = string
  default     = ""
}

variable "ses_mail_from_subdomain" {
  description = "Subdomain prefix for custom MAIL FROM domain (e.g. 'mail' creates mail.example.com)."
  type        = string
  default     = "mail"
}

variable "verification_bucket_name" {
  description = "S3 bucket name for verification document uploads. Leave empty to auto-generate."
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Observability (CloudTrail and CloudWatch Alarms)
#--------------------------------------------------------------
variable "enable_cloudtrail" {
  description = "Enable AWS CloudTrail."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Create CloudWatch alarms for ECS, RDS, and ALB."
  type        = bool
  default     = true
}

variable "alarm_notification_email" {
  description = "Email endpoint subscribed to the CloudWatch alarm SNS topic. Required for production-like environments when alarms are enabled unless alarm_notification_topic_arn is provided."
  type        = string
  default     = ""
}

variable "alarm_notification_topic_arn" {
  description = "Existing SNS topic ARN for CloudWatch alarm notifications. Leave empty to create and use the repo-managed alarm topic."
  type        = string
  default     = ""
}

variable "enable_codedeploy" {
  description = "Create CodeDeploy applications and deployment groups for ECS and Lambda services."
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# Backup Configuration
#--------------------------------------------------------------
variable "enable_backup" {
  description = "Enable AWS Backup vault and plan for RDS and DynamoDB."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups."
  type        = number
  default     = 30
}

check "stateful_service_scale_out_guardrails" {
  assert {
    condition     = var.enable_stateful_service_scale_out || var.user_desired_count == 1
    error_message = "user_desired_count must be 1 unless enable_stateful_service_scale_out is true."
  }

  assert {
    condition     = var.enable_stateful_service_scale_out || var.transaction_desired_count == 1
    error_message = "transaction_desired_count must be 1 unless enable_stateful_service_scale_out is true."
  }
}

check "prod_database_guardrails" {
  assert {
    condition     = !contains(["prod", "production"], lower(trimspace(var.environment))) || !var.enforce_strict_prod_guardrails || var.db_multi_az
    error_message = "For environment=prod, db_multi_az must be true."
  }

  assert {
    condition     = !contains(["prod", "production"], lower(trimspace(var.environment))) || !var.enforce_strict_prod_guardrails || var.db_backup_retention_days >= 7
    error_message = "For environment=prod, db_backup_retention_days must be at least 7."
  }

  assert {
    condition     = !contains(["prod", "production"], lower(trimspace(var.environment))) || !var.enforce_strict_prod_guardrails || !var.db_skip_final_snapshot
    error_message = "For environment=prod, db_skip_final_snapshot must be false."
  }

  assert {
    condition     = !contains(["prod", "production"], lower(trimspace(var.environment))) || !var.enforce_strict_prod_guardrails || var.db_deletion_protection
    error_message = "For environment=prod, db_deletion_protection must be true."
  }
}

check "prod_secret_strength_guardrails" {
  assert {
    condition = !contains(["prod", "production"], lower(trimspace(var.environment))) || (
      length(trimspace(var.jwt_hmac_secret)) >= 32 &&
      trimspace(var.jwt_hmac_secret) != "dev-only-insecure-secret"
    )
    error_message = "For environment=prod, jwt_hmac_secret must be explicitly set and at least 32 characters."
  }

  assert {
    condition = !contains(["prod", "production"], lower(trimspace(var.environment))) || (
      length(trimspace(var.root_admin_password)) >= 16 &&
      can(regex("[A-Z]", var.root_admin_password)) &&
      can(regex("[a-z]", var.root_admin_password)) &&
      can(regex("[0-9]", var.root_admin_password)) &&
      can(regex("[^A-Za-z0-9]", var.root_admin_password)) &&
      trimspace(var.root_admin_password) != "admin123"
    )
    error_message = "For environment=prod, root_admin_password must be >=16 chars and include upper, lower, number, and symbol."
  }
}

check "production_like_mfa_guardrails" {
  assert {
    condition     = !var.enable_cognito || !contains(["prod", "production", "integration"], lower(trimspace(var.environment))) || upper(trimspace(var.cognito_mfa_configuration)) != "OFF"
    error_message = "For production-like environments with enable_cognito=true, cognito_mfa_configuration must be OPTIONAL or ON."
  }
}

check "alarm_notification_endpoint_guardrails" {
  assert {
    condition = !var.enable_cloudwatch_alarms || !contains(["prod", "production", "integration"], lower(trimspace(var.environment))) || (
      trimspace(var.alarm_notification_email) != "" ||
      trimspace(var.alarm_notification_topic_arn) != ""
    )
    error_message = "For production-like environments with enable_cloudwatch_alarms=true, set alarm_notification_email or alarm_notification_topic_arn."
  }
}

check "lambda_artifact_paths_root" {
  assert {
    condition = !var.enable_log_lambda || (
      trimspace(var.log_lambda_zip_path) != "" &&
      fileexists(var.log_lambda_zip_path) &&
      filesize(var.log_lambda_zip_path) > 0
    )
    error_message = "When enable_log_lambda is true, log_lambda_zip_path must point to an existing, non-empty zip file."
  }

  assert {
    condition = !var.enable_sftp_transaction_collector || (
      trimspace(var.sftp_transaction_collector_zip_path) != "" &&
      fileexists(var.sftp_transaction_collector_zip_path) &&
      filesize(var.sftp_transaction_collector_zip_path) > 0
    )
    error_message = "When enable_sftp_transaction_collector is true, sftp_transaction_collector_zip_path must point to an existing, non-empty zip file."
  }

  assert {
    condition = !var.enable_aml_lambda || (
      trimspace(var.aml_lambda_zip_path) != "" &&
      fileexists(var.aml_lambda_zip_path) &&
      filesize(var.aml_lambda_zip_path) > 0
    )
    error_message = "When enable_aml_lambda is true, aml_lambda_zip_path must point to an existing, non-empty zip file."
  }

  assert {
    condition = !var.enable_audit_pipeline || (
      trimspace(var.audit_consumer_zip_path) != "" &&
      fileexists(var.audit_consumer_zip_path) &&
      filesize(var.audit_consumer_zip_path) > 0
    )
    error_message = "When enable_audit_pipeline is true, audit_consumer_zip_path must point to an existing, non-empty zip file."
  }

  assert {
    condition = !var.enable_aml_pipeline || (
      trimspace(var.aml_consumer_zip_path) != "" &&
      fileexists(var.aml_consumer_zip_path) &&
      filesize(var.aml_consumer_zip_path) > 0
    )
    error_message = "When enable_aml_pipeline is true, aml_consumer_zip_path must point to an existing, non-empty zip file."
  }

  assert {
    condition = !var.enable_verification_pipeline || (
      trimspace(var.verification_zip_path) != "" &&
      fileexists(var.verification_zip_path) &&
      filesize(var.verification_zip_path) > 0
    )
    error_message = "When enable_verification_pipeline is true, verification_zip_path must point to an existing, non-empty zip file."
  }
}

check "prod_network_and_pipeline_guardrails" {
  assert {
    condition     = !contains(["prod", "production"], lower(trimspace(var.environment))) || !var.enforce_strict_prod_guardrails || var.enable_multi_az_nat
    error_message = "For environment=prod, enable_multi_az_nat must be true to avoid single-AZ NAT dependency."
  }

  assert {
    condition     = !contains(["prod", "production"], lower(trimspace(var.environment))) || !var.enforce_strict_prod_guardrails || var.enable_nat_gateway
    error_message = "For environment=prod, enable_nat_gateway must be true."
  }

  assert {
    condition     = !var.enable_verification_pipeline || var.enable_log_lambda
    error_message = "enable_verification_pipeline requires enable_log_lambda=true so the verification feedback Lambda receives a non-empty LOG_API_BASE_URL."
  }

  assert {
    condition = !var.enable_verification_pipeline || (
      trimspace(var.app_domain_name) != "" ||
      trimspace(var.verification_frontend_base_url) != ""
    )
    error_message = "When enable_verification_pipeline is true, set app_domain_name or verification_frontend_base_url so verification emails have a stable public frontend link target."
  }
}

check "custom_domain_contract_guardrails" {
  assert {
    condition = (
      trimspace(var.existing_frontend_certificate_arn) == "" &&
      trimspace(var.existing_alb_certificate_arn) == ""
      ) || (
      trimspace(var.existing_frontend_certificate_arn) != "" &&
      trimspace(var.existing_alb_certificate_arn) != ""
    )
    error_message = "Provide both existing_frontend_certificate_arn and existing_alb_certificate_arn together, or leave both empty."
  }

  assert {
    condition = trimspace(var.app_domain_name) == "" || (
      var.create_acm_certificates || (
        trimspace(var.existing_frontend_certificate_arn) != "" &&
        trimspace(var.existing_alb_certificate_arn) != ""
      )
    )
    error_message = "When app_domain_name is set, either create_acm_certificates must be true or both existing certificate ARNs must be provided."
  }

  assert {
    condition     = trimspace(var.app_domain_name) != "" || !var.create_acm_certificates
    error_message = "create_acm_certificates can only be true when app_domain_name is set."
  }

  assert {
    condition = trimspace(var.app_domain_name) != "" || (
      trimspace(var.existing_frontend_certificate_arn) == "" &&
      trimspace(var.existing_alb_certificate_arn) == ""
    )
    error_message = "Existing ACM certificate ARNs require app_domain_name to be set."
  }

  assert {
    condition     = !(var.manage_route53_records || var.manage_acm_dns_validation_records) || trimspace(var.route53_hosted_zone_id) != ""
    error_message = "route53_hosted_zone_id must be set when Terraform is configured to manage any Route53 records."
  }
}

check "natless_ecs_guardrails" {
  assert {
    condition     = var.enable_nat_gateway || var.ecs_use_public_subnets
    error_message = "When enable_nat_gateway is false, ecs_use_public_subnets must be true so ECS tasks still have outbound internet access."
  }

  assert {
    condition     = !var.ecs_use_public_subnets || var.ecs_assign_public_ip
    error_message = "When ecs_use_public_subnets is true, ecs_assign_public_ip must be true."
  }
}
