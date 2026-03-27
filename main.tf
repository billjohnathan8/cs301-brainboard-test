#--------------------------------------------------------------
# CS301 G2T3 Project (Team CRUMBS) - Main Infrastructure Configuration
#
# This file orchestrates all Terraform modules that compose the
# ScroogeBank CRM AWS infrastructure. Each module block represents
# a single AWS service domain wired together through shared outputs.
#--------------------------------------------------------------

data "aws_caller_identity" "current" {}

#--------------------------------------------------------------
# Network Module
# VPC, public/private/DB subnets, NAT Gateway, route tables, flow logs
#--------------------------------------------------------------
module "network" {
  source = "./modules/network"

  name_prefix             = local.name_prefix
  az_count                = var.az_count
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  db_subnet_cidrs         = var.db_subnet_cidrs
  enable_vpc_flow_logs    = var.enable_vpc_flow_logs
  flow_log_retention_days = var.cloudwatch_log_retention_days
  enable_multi_az_nat     = var.enable_multi_az_nat
  enable_nat_gateway      = var.enable_nat_gateway
}

#--------------------------------------------------------------
# Security Module
# Security groups, IAM roles/policies, and Secrets Manager entries
#--------------------------------------------------------------
module "security" {
  source = "./modules/security"

  project_name              = var.project_name
  environment               = var.environment
  name_prefix               = local.name_prefix
  aws_region                = var.aws_region
  vpc_id                    = module.network.vpc_id
  db_port                   = var.db_port
  db_username               = var.db_username
  jwt_hmac_secret           = var.jwt_hmac_secret
  root_admin_password       = var.root_admin_password
  aml_sftp_key_secret_arn   = var.aml_sftp_key_secret_arn
  create_backend_iam_policy = var.create_backend_iam_policy
  backend_state_bucket_name = var.backend_state_bucket_name
  backend_lock_table_name   = var.backend_lock_table_name

  lab_role_arn  = var.lab_role_arn
  lab_role_name = var.lab_role_name

  enable_audit_pipeline             = var.enable_audit_pipeline
  enable_aml_pipeline               = var.enable_aml_pipeline
  enable_verification_pipeline      = var.enable_verification_pipeline
  enable_sftp_transaction_collector = var.enable_sftp_transaction_collector
  audit_sqs_arn                     = module.sqs.audit_queue_arn
  audit_dlq_arn                     = module.sqs.audit_dlq_arn
  aml_sqs_arn                       = module.sqs.aml_queue_arn
  aml_dlq_arn                       = module.sqs.aml_dlq_arn
  audit_dynamodb_table_arn          = module.dynamodb.audit_logs_table_arn
  aml_dynamodb_table_arn            = module.dynamodb.aml_reports_table_arn
  verification_bucket_arn           = module.s3.verification_bucket_arn
  transaction_sftp_bucket_arn       = module.s3.transaction_sftp_bucket_arn
  verification_sns_topic_arn        = module.sns.verification_topic_arn
}

#--------------------------------------------------------------
# ECR Module
# Elastic Container Registry for backend service images
#--------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  name_prefix          = local.name_prefix
  ecr_repository_name  = var.ecr_repository_name
  ecr_repository_names = var.ecr_repository_names
}

#--------------------------------------------------------------
# RDS Module
# PostgreSQL database instance with KMS encryption and subnet group
#--------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project_name                 = var.project_name
  environment                  = var.environment
  name_prefix                  = local.name_prefix
  private_subnet_ids           = local.db_subnet_ids
  db_security_group_id         = module.security.db_security_group_id
  db_password_value            = module.security.db_password_value
  db_name                      = var.db_name
  db_username                  = var.db_username
  db_port                      = var.db_port
  db_instance_class            = var.db_instance_class
  db_engine_version            = var.db_engine_version
  db_allocated_storage         = var.db_allocated_storage
  db_max_allocated_storage     = var.db_max_allocated_storage
  db_multi_az                  = var.db_multi_az
  db_backup_retention_days     = var.db_backup_retention_days
  db_skip_final_snapshot       = var.db_skip_final_snapshot
  db_deletion_protection       = var.db_deletion_protection
  performance_insights_enabled = var.rds_performance_insights_enabled
}

#--------------------------------------------------------------
# ACM Module
# Creates and validates SSL/TLS certificates for CloudFront (us-east-1)
# and ALB (primary region) with DNS validation via Route53.
#--------------------------------------------------------------
module "acm" {
  source = "./modules/acm"
  count  = local.create_acm_certificates ? 1 : 0

  name_prefix                   = local.name_prefix
  app_domain_name               = var.app_domain_name
  route53_zone_id               = var.route53_hosted_zone_id
  alb_origin_subdomain          = var.alb_origin_subdomain
  manage_dns_validation_records = var.manage_acm_dns_validation_records
  wait_for_validation           = var.acm_wait_for_validation

  providers = {
    aws.us_east_1      = aws.us_east_1
    aws.ap_southeast_1 = aws.ap_southeast_1
  }
}

#--------------------------------------------------------------
# ALB Module
# Application Load Balancer with path-based routing to ECS services
#--------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  name_prefix               = local.name_prefix
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  alb_security_group_id     = module.security.alb_security_group_id
  use_custom_domain         = local.use_custom_domain
  alb_certificate_arn       = local.alb_certificate_arn
  service_health_check_path = "/health"
  route53_zone_id           = var.route53_hosted_zone_id
  alb_subdomain             = var.alb_origin_subdomain
  manage_route53_record     = local.manage_route53_records
  enable_blue_green_tg      = var.enable_codedeploy

  depends_on = [module.acm]
}

#--------------------------------------------------------------
# Lambda Module
# Lambda functions: log service, AML ingestion, transaction ingestion,
# audit consumer, AML consumer, and verification
#--------------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  enable_log_lambda                              = var.enable_log_lambda
  project_name                                   = var.project_name
  environment                                    = var.environment
  name_prefix                                    = local.name_prefix
  cloudwatch_log_retention_days                  = var.cloudwatch_log_retention_days
  log_lambda_zip_path                            = var.log_lambda_zip_path
  log_lambda_memory_size                         = var.log_lambda_memory_size
  log_lambda_timeout_seconds                     = var.log_lambda_timeout_seconds
  private_subnet_ids                             = module.network.private_subnet_ids
  lambda_security_group_id                       = module.security.lambda_security_group_id
  log_lambda_role_arn                            = module.security.log_lambda_role_arn
  db_host                                        = module.rds.rds_endpoint
  db_port                                        = var.db_port
  db_name                                        = var.db_name
  db_username_secret_arn                         = module.security.db_username_secret_arn
  db_password_secret_arn                         = module.security.db_password_secret_arn
  jwt_hmac_secret_arn                            = module.security.jwt_hmac_secret_arn
  auth_mode                                      = lower(trimspace(var.auth_mode))
  cognito_issuer_url                             = var.cognito_issuer_url != "" ? var.cognito_issuer_url : (var.enable_cognito ? module.cognito[0].issuer_url : "")
  cognito_jwks_url                               = var.cognito_jwks_url != "" ? var.cognito_jwks_url : (var.enable_cognito ? module.cognito[0].jwks_url : "")
  cognito_audience                               = var.cognito_audience != "" ? var.cognito_audience : (var.enable_cognito ? module.cognito[0].app_client_id : "")
  enable_aml_lambda                              = var.enable_aml_lambda
  aml_lambda_zip_path                            = var.aml_lambda_zip_path
  aml_lambda_memory_size                         = var.aml_lambda_memory_size
  aml_lambda_timeout_seconds                     = var.aml_lambda_timeout_seconds
  aml_lambda_role_arn                            = module.security.aml_lambda_role_arn
  aml_schedule_expression                        = var.aml_schedule_expression
  aml_sftp_host                                  = var.aml_sftp_host
  aml_sftp_port                                  = var.aml_sftp_port
  aml_sftp_user                                  = var.aml_sftp_user
  aml_sftp_key_secret_arn                        = var.aml_sftp_key_secret_arn
  aml_sftp_remote_path                           = var.aml_sftp_remote_path
  aml_entity_id                                  = var.aml_entity_id
  crm_api_base_url                               = local.crm_api_base_url
  enable_sftp_transaction_collector              = var.enable_sftp_transaction_collector
  sftp_transaction_collector_zip_path            = var.sftp_transaction_collector_zip_path
  sftp_transaction_collector_memory_size         = var.sftp_transaction_collector_memory_size
  sftp_transaction_collector_timeout_seconds     = var.sftp_transaction_collector_timeout_seconds
  sftp_transaction_collector_role_arn            = module.security.sftp_transaction_collector_role_arn
  sftp_transaction_collector_schedule_expression = var.sftp_transaction_collector_schedule_expression
  transaction_sftp_bucket_id                     = module.s3.transaction_sftp_bucket_id
  transaction_sftp_remote_prefix                 = var.transaction_sftp_remote_prefix
  transaction_import_api_url                     = "${local.transaction_import_api_base_url}${var.transaction_import_api_path}"

  # Audit consumer Lambda
  enable_audit_consumer     = var.enable_audit_pipeline
  audit_consumer_zip_path   = var.audit_consumer_zip_path
  audit_consumer_role_arn   = module.security.audit_consumer_lambda_role_arn
  audit_sqs_arn             = module.sqs.audit_queue_arn
  audit_dynamodb_table_name = module.dynamodb.audit_logs_table_name

  # AML consumer Lambda
  enable_aml_consumer     = var.enable_aml_pipeline
  aml_consumer_zip_path   = var.aml_consumer_zip_path
  aml_consumer_role_arn   = module.security.aml_consumer_lambda_role_arn
  aml_sqs_arn             = module.sqs.aml_queue_arn
  aml_dynamodb_table_name = module.dynamodb.aml_reports_table_name

  # Verification Lambda
  enable_verification_lambda       = var.enable_verification_pipeline
  verification_zip_path            = var.verification_zip_path
  verification_role_arn            = module.security.verification_lambda_role_arn
  verification_bucket_arn          = module.s3.verification_bucket_arn
  verification_bucket_id           = module.s3.verification_bucket_id
  verification_sns_topic_arn       = module.sns.verification_topic_arn
  ses_sender_email                 = var.ses_sender_email
  verification_frontend_base_url   = local.verification_frontend_base_url
  log_api_base_url                 = var.enable_log_lambda ? module.apigateway[0].log_api_base_url : ""
  verification_jwt_hmac_secret_arn = module.security.jwt_hmac_secret_arn
}

#--------------------------------------------------------------
# API Gateway Module
# HTTP API for the log service Lambda (fronted by CloudFront)
#--------------------------------------------------------------
module "apigateway" {
  source = "./modules/apigateway"
  count  = var.enable_log_lambda ? 1 : 0

  project_name                  = var.project_name
  environment                   = var.environment
  name_prefix                   = local.name_prefix
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
  use_custom_domain             = local.use_custom_domain
  app_domain_name               = var.app_domain_name
  log_lambda_invoke_arn         = module.lambda.log_lambda_invoke_arn
  log_lambda_function_name      = module.lambda.log_lambda_name
}

#--------------------------------------------------------------
# ECS Module
# Fargate cluster with user, client, and transaction services,
# service discovery, and CloudWatch logging.
# Note: by default only stateless services are autoscaled; stateful
# service scale-out is feature-gated by enable_stateful_service_scale_out.
#--------------------------------------------------------------
module "ecs" {
  source = "./modules/ecs"

  project_name = var.project_name
  environment  = var.environment
  name_prefix  = local.name_prefix
  aws_region   = var.aws_region

  vpc_id                                          = module.network.vpc_id
  service_subnet_ids                              = local.ecs_subnet_ids
  assign_public_ip                                = var.ecs_assign_public_ip
  ecs_service_security_group_id                   = module.security.ecs_service_security_group_id
  cloudwatch_log_retention_days                   = var.cloudwatch_log_retention_days
  enable_container_insights                       = var.enable_ecs_container_insights
  target_group_arns                               = module.alb.target_group_arns
  service_health_check_path                       = "/health"
  ecr_repository_urls                             = module.ecr.repository_urls
  ecs_task_execution_role_arn                     = module.security.ecs_task_execution_role_arn
  ecs_task_role_arns                              = module.security.ecs_task_role_arns
  root_admin_email                                = var.root_admin_email
  auth_mode                                       = lower(trimspace(var.auth_mode))
  cognito_issuer_url                              = var.cognito_issuer_url != "" ? var.cognito_issuer_url : (var.enable_cognito ? module.cognito[0].issuer_url : "")
  cognito_jwks_url                                = var.cognito_jwks_url != "" ? var.cognito_jwks_url : (var.enable_cognito ? module.cognito[0].jwks_url : "")
  cognito_audience                                = var.cognito_audience != "" ? var.cognito_audience : (var.enable_cognito ? module.cognito[0].app_client_id : "")
  transaction_mock_sftp_root                      = var.transaction_mock_sftp_root
  transaction_import_s3_bucket                    = module.s3.transaction_sftp_bucket_name
  transaction_import_s3_region                    = var.aws_region
  transaction_import_s3_endpoint                  = var.transaction_import_s3_endpoint
  transaction_import_s3_path_style_access_enabled = var.transaction_import_s3_path_style_access_enabled
  db_jdbc_url                                     = module.rds.db_jdbc_url
  log_api_base_url                                = var.enable_log_lambda ? module.apigateway[0].log_api_base_url : ""
  verification_email_provider                     = var.enable_verification_pipeline ? "ses" : "mock"
  ses_sender_email                                = var.ses_sender_email
  verification_sns_topic_arn                      = module.sns.verification_topic_arn
  verification_documents_bucket                   = module.s3.verification_bucket_id
  root_admin_password_secret_arn                  = module.security.root_admin_password_secret_arn
  jwt_hmac_secret_arn                             = module.security.jwt_hmac_secret_arn
  db_username_secret_arn                          = module.security.db_username_secret_arn
  db_password_secret_arn                          = module.security.db_password_secret_arn
  ecs_task_cpu                                    = var.ecs_task_cpu
  ecs_task_memory                                 = var.ecs_task_memory
  ecs_min_capacity                                = var.ecs_min_capacity
  ecs_max_capacity                                = var.ecs_max_capacity
  ecs_target_cpu_utilization                      = var.ecs_target_cpu_utilization
  ecs_target_memory_utilization                   = var.ecs_target_memory_utilization
  enable_stateful_service_scale_out               = var.enable_stateful_service_scale_out
  enable_service_discovery                        = var.enable_service_discovery
  alb_dns_name                                    = module.alb.alb_dns_name
  use_codedeploy_controller                       = var.enable_codedeploy
  enable_deployment_alarms                        = var.enable_cloudwatch_alarms
  deployment_alarm_names = var.enable_cloudwatch_alarms ? {
    for svc in ["user", "client", "transaction"] :
    svc => ["${local.name_prefix}-${svc}-unhealthy-hosts"]
  } : {}

  image_tags = {
    user        = var.user_image_tag
    client      = var.client_image_tag
    transaction = var.transaction_image_tag
  }

  desired_counts = {
    user        = var.user_desired_count
    client      = var.client_desired_count
    transaction = var.transaction_desired_count
  }
}

#--------------------------------------------------------------
# S3 Module
# Frontend static asset bucket, verification document bucket,
# and transaction ingestion source bucket (legacy 'sftp' naming).
#--------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  frontend_bucket_name           = local.frontend_bucket_name
  frontend_bucket_force_destroy  = var.frontend_bucket_force_destroy
  frontend_bucket_allow_public   = var.frontend_bucket_allow_public
  enable_verification_bucket     = var.enable_verification_pipeline
  verification_bucket_name       = local.verification_bucket_name
  enable_transaction_sftp_bucket = var.enable_sftp_transaction_collector
  transaction_sftp_bucket_name   = local.transaction_sftp_bucket_name
}

#--------------------------------------------------------------
# WAF Module
# WAFv2 Web ACL with AWS Managed Rules (Common + SQLi) for CloudFront
#--------------------------------------------------------------
module "waf" {
  source = "./modules/waf"

  name_prefix = local.name_prefix
  enable_waf  = var.enable_waf

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

#--------------------------------------------------------------
# CloudFront Module
# CDN distribution with S3 frontend, ALB backend, and API Gateway origins
#--------------------------------------------------------------
module "cloudfront" {
  source = "./modules/cloudfront"
  count  = var.enable_cloudfront ? 1 : 0

  name_prefix                          = local.name_prefix
  use_custom_domain                    = local.use_custom_domain
  app_domain_name                      = var.app_domain_name
  cloudfront_price_class               = var.cloudfront_price_class
  frontend_certificate_arn             = local.frontend_certificate_arn
  alb_origin_domain_name               = local.alb_origin_domain_name
  alb_dns_name                         = module.alb.alb_dns_name
  frontend_bucket_id                   = module.s3.frontend_bucket_id
  frontend_bucket_arn                  = module.s3.frontend_bucket_arn
  frontend_bucket_regional_domain_name = module.s3.frontend_bucket_regional_domain_name
  enable_log_api_origin                = var.enable_log_lambda
  log_api_origin_domain_name           = var.enable_log_lambda ? module.apigateway[0].log_api_origin_domain_name : null
  waf_arn                              = module.waf.waf_arn
  route53_zone_id                      = var.route53_hosted_zone_id
  manage_route53_record                = local.manage_route53_records
  enable_cloudfront_oac                = var.enable_cloudfront_oac
}

#--------------------------------------------------------------
# Cognito Module
# User pool and app client for authentication (feature-gated)
#--------------------------------------------------------------
module "cognito" {
  source = "./modules/cognito"
  count  = var.enable_cognito ? 1 : 0

  name_prefix                  = local.name_prefix
  aws_region                   = var.aws_region
  allow_admin_create_user_only = true
  callback_urls                = var.cognito_callback_urls
  logout_urls                  = var.cognito_logout_urls
  cognito_domain_prefix        = var.cognito_domain_prefix
  mfa_configuration            = upper(trimspace(var.cognito_mfa_configuration))
}

#--------------------------------------------------------------
# SQS Module
# Message queues for audit and AML async pipelines (feature-gated)
#--------------------------------------------------------------
module "sqs" {
  source = "./modules/sqs"

  name_prefix           = local.name_prefix
  environment           = var.environment
  enable_audit_pipeline = var.enable_audit_pipeline
  enable_aml_pipeline   = var.enable_aml_pipeline
}

#--------------------------------------------------------------
# SNS Module
# Notification topics for verification pipeline (feature-gated)
#--------------------------------------------------------------
module "sns" {
  source = "./modules/sns"

  name_prefix                  = local.name_prefix
  environment                  = var.environment
  enable_verification_pipeline = var.enable_verification_pipeline
  notification_email           = var.ses_notification_email
  enable_alarm_topic           = var.enable_cloudwatch_alarms && trimspace(var.alarm_notification_topic_arn) == ""
  alarm_notification_email     = var.alarm_notification_email
}

#--------------------------------------------------------------
# SES Module
# Email identities and DKIM/SPF configuration for outbound email
#--------------------------------------------------------------
module "ses" {
  source = "./modules/ses"

  enable_ses             = true
  sender_email           = var.ses_sender_email
  domain                 = var.ses_domain
  mail_from_subdomain    = var.ses_mail_from_subdomain
  notification_topic_arn = module.sns.verification_topic_arn
}

#--------------------------------------------------------------
# DynamoDB Module
# Audit logs and AML reports tables (feature-gated)
#--------------------------------------------------------------
module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix        = local.name_prefix
  enable_audit_table = var.enable_audit_pipeline
  enable_aml_table   = var.enable_aml_pipeline
}

#--------------------------------------------------------------
# Observability Module
# CloudTrail audit logging and CloudWatch alarms for ECS, RDS, ALB
#--------------------------------------------------------------
module "observability" {
  source = "./modules/observability"

  name_prefix                  = local.name_prefix
  enable_cloudtrail            = var.enable_cloudtrail
  alarm_notification_topic_arn = trimspace(var.alarm_notification_topic_arn) != "" ? trimspace(var.alarm_notification_topic_arn) : module.sns.alarm_topic_arn

  enable_ecs_alarms = var.enable_cloudwatch_alarms
  ecs_cluster_name  = module.ecs.ecs_cluster_name
  ecs_service_names = toset(["user", "client", "transaction"])

  enable_rds_alarms       = var.enable_cloudwatch_alarms
  rds_instance_identifier = module.rds.rds_instance_identifier

  enable_alb_alarms         = var.enable_cloudwatch_alarms
  alb_arn_suffix            = module.alb.alb_arn_suffix
  target_group_arn_suffixes = module.alb.target_group_arn_suffixes

  enable_ses_alarms = var.enable_cloudwatch_alarms && var.enable_verification_pipeline
  ses_identity      = var.ses_domain != "" ? var.ses_domain : var.ses_sender_email

  enable_dashboard = var.enable_cloudwatch_alarms
  aws_region       = var.aws_region
}

#--------------------------------------------------------------
# Backup Module
# AWS Backup vault and daily plan covering RDS and DynamoDB
#--------------------------------------------------------------
module "backup" {
  source = "./modules/backup"

  name_prefix           = local.name_prefix
  enable_backup         = var.enable_backup
  backup_retention_days = var.backup_retention_days
  rds_instance_arn      = module.rds.rds_instance_arn
  dynamodb_table_arns   = local.dynamodb_backup_arns
}

#--------------------------------------------------------------
# CodeDeploy Module
# Deployment applications/groups for ECS services and Lambda functions
#--------------------------------------------------------------
module "codedeploy" {
  source = "./modules/codedeploy"

  enable_codedeploy            = var.enable_codedeploy
  name_prefix                  = local.name_prefix
  ecs_cluster_name             = module.ecs.ecs_cluster_name
  ecs_service_names            = module.ecs.ecs_service_names
  alb_listener_arn             = module.alb.primary_listener_arn
  ecs_blue_target_group_names  = module.alb.target_group_names
  ecs_green_target_group_names = module.alb.target_group_green_names

  lambda_deployments = {
    log = {
      enabled       = var.enable_log_lambda
      function_name = module.lambda.log_lambda_name
      alias_name    = module.lambda.log_lambda_alias_name
    }
    aml = {
      enabled       = var.enable_aml_lambda
      function_name = module.lambda.aml_lambda_name
      alias_name    = module.lambda.aml_lambda_alias_name
    }
    sftp-transaction-collector = {
      enabled       = var.enable_sftp_transaction_collector
      function_name = module.lambda.sftp_transaction_collector_name
      alias_name    = module.lambda.sftp_transaction_collector_alias_name
    }
    verification = {
      enabled       = var.enable_verification_pipeline
      function_name = module.lambda.verification_lambda_name
      alias_name    = module.lambda.verification_lambda_alias_name
    }
  }
}
