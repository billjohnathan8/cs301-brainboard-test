# Auto-generated Brainboard import file
# Source: modules/*
# Purpose: visualize resources (not intended for Terraform apply)
# Note: known Brainboard-unsupported resources are omitted.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" {
  region                      = "ap-southeast-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
}

provider "aws" {
  alias                       = "us_east_1"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
}

provider "aws" {
  alias                       = "ap_southeast_1"
  region                      = "ap-southeast-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
}

# ---- Module: alb ----
# Variables for module alb
variable "alb__alb_certificate_arn" {
  type    = any
  default = null
}

variable "alb__alb_security_group_id" {
  type    = any
  default = null
}

variable "alb__alb_subdomain" {
  type    = any
  default = null
}

variable "alb__enable_blue_green_tg" {
  type    = any
  default = null
}

variable "alb__manage_route53_record" {
  type    = any
  default = false
}

variable "alb__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "alb__public_subnet_ids" {
  type    = any
  default = null
}

variable "alb__route53_zone_id" {
  type    = any
  default = null
}

variable "alb__service_health_check_path" {
  type    = any
  default = null
}

variable "alb__use_custom_domain" {
  type    = any
  default = false
}

variable "alb__vpc_id" {
  type    = any
  default = null
}

# Source: modules/alb/main.tf

locals {
  # Route groups are ordered by listener-rule priority (lower value = evaluated first).
  # A dedicated exception for `/api/clients/*/transactions*` is defined below with a
  # higher precedence than generic client routes.
  service_routing = {
    user = {
      priority      = 10
      path_patterns = ["/api/auth*", "/api/users*", "/api/v1/users*", "/api/v1/health", "/api/logs*"]
    }
    client = {
      priority      = 20
      path_patterns = ["/api/clients*", "/api/accounts*", "/api/v1/clients*", "/api/communications*", "/api/aml*"]
    }
    transaction = {
      priority      = 30
      path_patterns = ["/api/transactions*"]
    }
  }
}

# Source: modules/alb/main.tf

resource "aws_lb" "alb__crm" {
  name                       = substr("${var.alb__name_prefix}-alb", 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb__alb_security_group_id]
  subnets                    = var.alb__public_subnet_ids
  preserve_host_header       = true
  drop_invalid_header_fields = true
}

# Source: modules/alb/main.tf

# Source: modules/alb/main.tf

# Source: modules/alb/main.tf

# Source: modules/alb/main.tf

# Source: modules/alb/main.tf

# Source: modules/alb/main.tf

# Source: modules/alb/route53.tf

resource "aws_route53_record" "alb__alb" {
  count = var.alb__manage_route53_record && var.alb__use_custom_domain && var.alb__route53_zone_id != "" ? 1 : 0

  zone_id = var.alb__route53_zone_id
  name    = var.alb__alb_subdomain
  type    = "A"

  set_identifier = "alb__alb-${count.index}"

  multivalue_answer_routing_policy = true

  alias {
    name                   = aws_lb.alb__crm.dns_name
    zone_id                = aws_lb.alb__crm.zone_id
    evaluate_target_health = true
  }

  lifecycle {
    # Prevent accidental deletion of DNS record
    prevent_destroy = true
    # Ignore changes to zone_id to prevent replacement if zone is recreated
    ignore_changes = [zone_id]
  }
}

# ---- Module: apigateway ----
# Variables for module apigateway
variable "apigateway__app_domain_name" {
  type    = any
  default = null
}

variable "apigateway__cloudwatch_log_retention_days" {
  type    = any
  default = 30
}

variable "apigateway__environment" {
  type    = any
  default = "prod"
}

variable "apigateway__log_lambda_function_name" {
  type    = any
  default = null
}

variable "apigateway__log_lambda_invoke_arn" {
  type    = any
  default = null
}

variable "apigateway__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "apigateway__project_name" {
  type    = any
  default = "scroogebank-crm"
}

variable "apigateway__use_custom_domain" {
  type    = any
  default = false
}

# Source: modules/apigateway/main.tf

locals {
  log_api_route_keys = toset([
    "GET /health",
    "GET /api/v1/health",
    "GET /api/v1/logs/health",
    "GET /api/logs",
    "POST /api/logs",
    "GET /api/logs/{logId}",
    "PUT /api/logs/{logId}",
    "DELETE /api/logs/{logId}",
    "GET /api/clients/{clientId}/logs",
    "GET /api/aml/alerts",
    "POST /api/aml/alerts",
    "GET /api/aml/alerts/{alertId}",
    "PUT /api/aml/alerts/{alertId}/review",
    "POST /api/communications",
    "GET /api/communications/queued",
    "GET /api/communications/{communicationId}",
    "PATCH /api/communications/{communicationId}/status",
    "PATCH /api/communications/provider/{providerMessageId}/status",
    "GET /api/clients/{clientId}/communications",
  ])
}

# Source: modules/apigateway/main.tf

resource "aws_apigatewayv2_api" "apigateway__log" {
  name          = "${var.apigateway__name_prefix}-log-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.apigateway__use_custom_domain ? ["https://${var.apigateway__app_domain_name}"] : ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }
}

# Source: modules/apigateway/main.tf

# Source: modules/apigateway/main.tf

# Source: modules/apigateway/main.tf

# Source: modules/apigateway/main.tf

# Source: modules/apigateway/main.tf

# Source: modules/apigateway/main.tf

# ---- Module: backup ----
# Variables for module backup
variable "backup__backup_retention_days" {
  type    = any
  default = 30
}

variable "backup__backup_schedule" {
  type    = any
  default = null
}

variable "backup__dynamodb_table_arns" {
  type    = any
  default = null
}

variable "backup__enable_backup" {
  type    = any
  default = true
}

variable "backup__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "backup__rds_instance_arn" {
  type    = any
  default = null
}

# Source: modules/backup/main.tf

resource "aws_backup_vault" "backup__this" {
  count = var.backup__enable_backup ? 1 : 0

  name = "${var.backup__name_prefix}-vault"

  tags = {
    Name = "${var.backup__name_prefix}-backup-vault"
  }
}

# Source: modules/backup/main.tf

resource "aws_backup_plan" "backup__this" {
  count = var.backup__enable_backup ? 1 : 0

  name = "${var.backup__name_prefix}-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.backup__this[0].name
    schedule          = var.backup__backup_schedule

    lifecycle {
      delete_after = var.backup__backup_retention_days
    }
  }

  tags = {
    Name = "${var.backup__name_prefix}-backup-plan"
  }
}

# Source: modules/backup/main.tf

# Source: modules/backup/main.tf

# Source: modules/backup/main.tf

# Source: modules/backup/main.tf

# Source: modules/backup/main.tf

# ---- Module: cloudfront ----
# Variables for module cloudfront
variable "cloudfront__alb_dns_name" {
  type    = any
  default = null
}

variable "cloudfront__alb_origin_domain_name" {
  type    = any
  default = null
}

variable "cloudfront__app_domain_name" {
  type    = any
  default = null
}

variable "cloudfront__cloudfront_price_class" {
  type    = any
  default = "PriceClass_100"
}

variable "cloudfront__enable_cloudfront_oac" {
  type    = any
  default = true
}

variable "cloudfront__enable_log_api_origin" {
  type    = any
  default = false
}

variable "cloudfront__frontend_bucket_arn" {
  type    = any
  default = null
}

variable "cloudfront__frontend_bucket_id" {
  type    = any
  default = null
}

variable "cloudfront__frontend_bucket_regional_domain_name" {
  type    = any
  default = null
}

variable "cloudfront__frontend_certificate_arn" {
  type    = any
  default = null
}

variable "cloudfront__log_api_origin_domain_name" {
  type    = any
  default = null
}

variable "cloudfront__manage_route53_record" {
  type    = any
  default = false
}

variable "cloudfront__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "cloudfront__route53_zone_id" {
  type    = any
  default = null
}

variable "cloudfront__use_custom_domain" {
  type    = any
  default = false
}

variable "cloudfront__waf_arn" {
  type    = any
  default = null
}

# Source: modules/cloudfront/main.tf
locals {
  cf_cache_policy_caching_optimized               = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  cf_cache_policy_caching_disabled                = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  cf_origin_request_policy_all_viewer             = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  cf_origin_request_policy_all_viewer_except_host = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
}

# Source: modules/cloudfront/main.tf

locals {
  log_api_path_patterns = toset([
    "/api/logs*",
    "/api/communications*",
    "/api/aml*",
    "/api/v1/logs*",
    "/api/clients/*/logs*",
    "/api/clients/*/communications*",
  ])
}

# Source: modules/cloudfront/main.tf

resource "aws_cloudfront_origin_access_control" "cloudfront__frontend" {
  count = var.cloudfront__enable_cloudfront_oac ? 1 : 0

  name                              = "${var.cloudfront__name_prefix}-frontend-oac"
  description                       = "CloudFront access control for frontend S3 bucket."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Source: modules/cloudfront/main.tf

resource "aws_cloudfront_distribution" "cloudfront__frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.cloudfront__cloudfront_price_class
  aliases             = var.cloudfront__use_custom_domain ? [var.cloudfront__app_domain_name] : []
  web_acl_id          = var.cloudfront__waf_arn

  origin {
    domain_name              = var.cloudfront__frontend_bucket_regional_domain_name
    origin_id                = "frontend-s3"
    origin_access_control_id = var.cloudfront__enable_cloudfront_oac ? aws_cloudfront_origin_access_control.cloudfront__frontend[0].id : null

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/brainboard-placeholder"
    }
  }

  origin {
    domain_name = var.cloudfront__use_custom_domain ? var.cloudfront__alb_origin_domain_name : var.cloudfront__alb_dns_name
    origin_id   = "backend-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.cloudfront__use_custom_domain ? "https-only" : "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  dynamic "origin" {
    for_each = var.cloudfront__enable_log_api_origin ? [1] : []
    content {
      domain_name = var.cloudfront__log_api_origin_domain_name
      origin_id   = "log-api-gateway"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true
    cache_policy_id        = local.cf_cache_policy_caching_optimized
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.cloudfront__enable_log_api_origin ? local.log_api_path_patterns : toset([])
    content {
      path_pattern             = ordered_cache_behavior.value
      target_origin_id         = "log-api-gateway"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
      cached_methods           = ["GET", "HEAD", "OPTIONS"]
      compress                 = true
      cache_policy_id          = local.cf_cache_policy_caching_disabled
      origin_request_policy_id = local.cf_origin_request_policy_all_viewer_except_host
    }
  }

  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "backend-alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    compress                 = true
    cache_policy_id          = local.cf_cache_policy_caching_disabled
    origin_request_policy_id = local.cf_origin_request_policy_all_viewer
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.cloudfront__use_custom_domain ? false : true
    acm_certificate_arn            = var.cloudfront__use_custom_domain ? var.cloudfront__frontend_certificate_arn : null
    ssl_support_method             = var.cloudfront__use_custom_domain ? "sni-only" : null
    minimum_protocol_version       = var.cloudfront__use_custom_domain ? "TLSv1.2_2021" : "TLSv1"
  }
}

# Source: modules/cloudfront/main.tf

locals {
  frontend_bucket_policy_statement = merge(
    {
      Sid    = "AllowCloudFrontRead"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action = ["s3:GetObject"]
      Resource = [
        "${var.cloudfront__frontend_bucket_arn}/*",
      ]
    },
    var.cloudfront__enable_cloudfront_oac ? {
      # OAC signs requests so S3 can verify SourceArn. Without OAC (Learner Lab),
      # CloudFront doesn't sign requests so this condition must be omitted.
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.cloudfront__frontend.arn
        }
      }
    } : {}
  )

  frontend_bucket_policy_json = jsonencode({
    Version   = "2012-10-17"
    Statement = [local.frontend_bucket_policy_statement]
  })
}

# Source: modules/cloudfront/main.tf

# Source: modules/cloudfront/route53.tf

resource "aws_route53_record" "cloudfront__cloudfront" {
  count = var.cloudfront__manage_route53_record && var.cloudfront__use_custom_domain && var.cloudfront__route53_zone_id != "" ? 1 : 0

  zone_id = var.cloudfront__route53_zone_id
  name    = var.cloudfront__app_domain_name
  type    = "A"

  set_identifier = "cloudfront__cloudfront-${count.index}"

  multivalue_answer_routing_policy = true

  alias {
    name                   = aws_cloudfront_distribution.cloudfront__frontend.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront__frontend.hosted_zone_id
    evaluate_target_health = false
  }

  lifecycle {
    # Prevent accidental deletion of DNS record
    prevent_destroy = true
    # Ignore changes to zone_id to prevent replacement if zone is recreated
    ignore_changes = [zone_id]
  }
}

# ---- Module: codedeploy ----
# Variables for module codedeploy
variable "codedeploy__alb_listener_arn" {
  type    = any
  default = null
}

variable "codedeploy__ecs_blue_target_group_names" {
  type    = any
  default = null
}

variable "codedeploy__ecs_cluster_name" {
  type    = any
  default = null
}

variable "codedeploy__ecs_green_target_group_names" {
  type    = any
  default = null
}

variable "codedeploy__ecs_service_names" {
  type    = any
  default = null
}

variable "codedeploy__enable_codedeploy" {
  type    = any
  default = true
}

variable "codedeploy__lambda_deployments" {
  type    = any
  default = null
}

variable "codedeploy__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

# Source: modules/codedeploy/main.tf

locals {
  lambda_enabled_deployments = {
    for service, cfg in var.codedeploy__lambda_deployments :
    service => cfg
    if cfg.enabled && trimspace(cfg.function_name) != "" && trimspace(cfg.alias_name) != ""
  }
}

# Source: modules/codedeploy/main.tf

# Source: modules/codedeploy/main.tf

# Source: modules/codedeploy/main.tf

# Source: modules/codedeploy/main.tf

# Source: modules/codedeploy/main.tf

# Source: modules/codedeploy/main.tf

# Source: modules/codedeploy/main.tf

# ---- Module: cognito ----
# Variables for module cognito
variable "cognito__access_token_validity_hours" {
  type    = any
  default = null
}

variable "cognito__allow_admin_create_user_only" {
  type    = any
  default = null
}

variable "cognito__aws_region" {
  type    = any
  default = "ap-southeast-1"
}

variable "cognito__callback_urls" {
  type    = any
  default = null
}

variable "cognito__cognito_domain_prefix" {
  type    = any
  default = null
}

variable "cognito__id_token_validity_hours" {
  type    = any
  default = null
}

variable "cognito__logout_urls" {
  type    = any
  default = null
}

variable "cognito__mfa_configuration" {
  type    = any
  default = null
}

variable "cognito__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "cognito__refresh_token_validity_days" {
  type    = any
  default = null
}

# Source: modules/cognito/main.tf

resource "aws_cognito_user_pool" "cognito__this" {
  name = "${var.cognito__name_prefix}-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = var.cognito__allow_admin_create_user_only
  }

  mfa_configuration = var.cognito__mfa_configuration

  dynamic "software_token_mfa_configuration" {
    for_each = var.cognito__mfa_configuration != "OFF" ? [1] : []
    content {
      enabled = true
    }
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your verification code"
    email_message        = "Your verification code is {####}. This code will expire in 24 hours."
  }

  tags = {
    Name = "${var.cognito__name_prefix}-user-pool"
  }
}

# Source: modules/cognito/main.tf

# Source: modules/cognito/main.tf

# Source: modules/cognito/main.tf

resource "aws_cognito_user_pool_client" "cognito__this" {
  name         = "${var.cognito__name_prefix}-app-client"
  user_pool_id = aws_cognito_user_pool.cognito__this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]

  supported_identity_providers = ["COGNITO"]

  callback_urls = var.cognito__callback_urls
  logout_urls   = var.cognito__logout_urls

  allowed_oauth_flows_user_pool_client = length(var.cognito__callback_urls) > 0
  allowed_oauth_flows                  = length(var.cognito__callback_urls) > 0 ? ["code"] : []
  allowed_oauth_scopes                 = length(var.cognito__callback_urls) > 0 ? ["openid", "email", "profile"] : []

  access_token_validity  = var.cognito__access_token_validity_hours
  id_token_validity      = var.cognito__id_token_validity_hours
  refresh_token_validity = var.cognito__refresh_token_validity_days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# Source: modules/cognito/main.tf

# ---- Module: dynamodb ----
# Variables for module dynamodb
variable "dynamodb__billing_mode" {
  type    = any
  default = "PAY_PER_REQUEST"
}

variable "dynamodb__enable_aml_table" {
  type    = any
  default = false
}

variable "dynamodb__enable_audit_table" {
  type    = any
  default = false
}

variable "dynamodb__enable_point_in_time_recovery" {
  type    = any
  default = true
}

variable "dynamodb__enable_ttl" {
  type    = any
  default = false
}

variable "dynamodb__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

# Source: modules/dynamodb/main.tf

resource "aws_dynamodb_table" "dynamodb__audit_logs" {
  count = var.dynamodb__enable_audit_table ? 1 : 0

  name         = "${var.dynamodb__name_prefix}-audit-logs"
  billing_mode = var.dynamodb__billing_mode
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "client_id"
    type = "S"
  }

  global_secondary_index {
    name            = "user-index"
    projection_type = "ALL"
    hash_key        = "user_id"
    range_key       = "sk"
  }

  global_secondary_index {
    name            = "client-index"
    projection_type = "ALL"
    hash_key        = "client_id"
    range_key       = "sk"
  }

  point_in_time_recovery {
    enabled = var.dynamodb__enable_point_in_time_recovery
  }

  ttl {
    attribute_name = "ttl"
    enabled        = var.dynamodb__enable_ttl
  }

  tags = {
    Name = "${var.dynamodb__name_prefix}-audit-logs"
  }
}

# Source: modules/dynamodb/main.tf

resource "aws_dynamodb_table" "dynamodb__aml_reports" {
  count = var.dynamodb__enable_aml_table ? 1 : 0

  name         = "${var.dynamodb__name_prefix}-aml-reports"
  billing_mode = var.dynamodb__billing_mode
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "entity_id"
    type = "S"
  }

  global_secondary_index {
    name            = "entity-index"
    projection_type = "ALL"
    hash_key        = "entity_id"
    range_key       = "sk"
  }

  point_in_time_recovery {
    enabled = var.dynamodb__enable_point_in_time_recovery
  }

  ttl {
    attribute_name = "ttl"
    enabled        = var.dynamodb__enable_ttl
  }

  tags = {
    Name = "${var.dynamodb__name_prefix}-aml-reports"
  }
}

# ---- Module: ecr ----
# Variables for module ecr
variable "ecr__ecr_repository_name" {
  type    = any
  default = null
}

variable "ecr__ecr_repository_names" {
  type    = any
  default = null
}

variable "ecr__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

# Source: modules/ecr/main.tf

locals {
  default_repository_names = {
    user        = var.ecr__ecr_repository_name != "" ? "${var.ecr__ecr_repository_name}-user" : "${var.ecr__name_prefix}-user"
    client      = var.ecr__ecr_repository_name != "" ? "${var.ecr__ecr_repository_name}-client" : "${var.ecr__name_prefix}-client"
    transaction = var.ecr__ecr_repository_name != "" ? "${var.ecr__ecr_repository_name}-transaction" : "${var.ecr__name_prefix}-transaction"
  }

  repository_names = merge(local.default_repository_names, var.ecr__ecr_repository_names)
}

# Source: modules/ecr/main.tf

resource "aws_ecr_repository" "ecr__service" {
  for_each = local.repository_names

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Source: modules/ecr/main.tf

# ---- Module: ecs ----
# Variables for module ecs
variable "ecs__alb_dns_name" {
  type    = any
  default = null
}

variable "ecs__assign_public_ip" {
  type    = any
  default = null
}

variable "ecs__auth_mode" {
  type    = any
  default = "hybrid"
}

variable "ecs__aws_region" {
  type    = any
  default = "ap-southeast-1"
}

variable "ecs__cloudwatch_log_retention_days" {
  type    = any
  default = 30
}

variable "ecs__cognito_audience" {
  type    = any
  default = null
}

variable "ecs__cognito_issuer_url" {
  type    = any
  default = null
}

variable "ecs__cognito_jwks_url" {
  type    = any
  default = null
}

variable "ecs__db_jdbc_url" {
  type    = any
  default = null
}

variable "ecs__db_password_secret_arn" {
  type    = any
  default = null
}

variable "ecs__db_username_secret_arn" {
  type    = any
  default = null
}

variable "ecs__deployment_alarm_names" {
  type    = any
  default = null
}

variable "ecs__desired_counts" {
  type    = any
  default = null
}

variable "ecs__ecr_repository_urls" {
  type    = any
  default = null
}

variable "ecs__ecs_max_capacity" {
  type    = any
  default = 2
}

variable "ecs__ecs_min_capacity" {
  type    = any
  default = null
}

variable "ecs__ecs_service_security_group_id" {
  type    = any
  default = null
}

variable "ecs__ecs_target_cpu_utilization" {
  type    = any
  default = null
}

variable "ecs__ecs_target_memory_utilization" {
  type    = any
  default = null
}

variable "ecs__ecs_task_cpu" {
  type    = any
  default = null
}

variable "ecs__ecs_task_execution_role_arn" {
  type    = any
  default = null
}

variable "ecs__ecs_task_memory" {
  type    = any
  default = null
}

variable "ecs__ecs_task_role_arns" {
  type    = any
  default = null
}

variable "ecs__enable_container_insights" {
  type    = any
  default = null
}

variable "ecs__enable_deployment_alarms" {
  type    = any
  default = null
}

variable "ecs__enable_service_discovery" {
  type    = any
  default = true
}

variable "ecs__enable_stateful_service_scale_out" {
  type    = any
  default = false
}

variable "ecs__environment" {
  type    = any
  default = "prod"
}

variable "ecs__image_tags" {
  type    = any
  default = null
}

variable "ecs__jwt_hmac_secret_arn" {
  type    = any
  default = null
}

variable "ecs__log_api_base_url" {
  type    = any
  default = null
}

variable "ecs__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "ecs__project_name" {
  type    = any
  default = "scroogebank-crm"
}

variable "ecs__root_admin_email" {
  type    = any
  default = null
}

variable "ecs__root_admin_password_secret_arn" {
  type    = any
  default = null
}

variable "ecs__service_health_check_path" {
  type    = any
  default = null
}

variable "ecs__service_subnet_ids" {
  type    = any
  default = null
}

variable "ecs__ses_sender_email" {
  type    = any
  default = "verification@crm.local"
}

variable "ecs__target_group_arns" {
  type    = any
  default = null
}

variable "ecs__transaction_import_s3_bucket" {
  type    = any
  default = null
}

variable "ecs__transaction_import_s3_endpoint" {
  type    = any
  default = null
}

variable "ecs__transaction_import_s3_path_style_access_enabled" {
  type    = any
  default = null
}

variable "ecs__transaction_import_s3_region" {
  type    = any
  default = null
}

variable "ecs__transaction_mock_sftp_root" {
  type    = any
  default = null
}

variable "ecs__use_codedeploy_controller" {
  type    = any
  default = null
}

variable "ecs__verification_documents_bucket" {
  type    = any
  default = null
}

variable "ecs__verification_email_provider" {
  type    = any
  default = null
}

variable "ecs__verification_sns_topic_arn" {
  type    = any
  default = null
}

variable "ecs__vpc_id" {
  type    = any
  default = null
}

# Source: modules/ecs/auto_scaling.tf

# Source: modules/ecs/auto_scaling.tf

# Source: modules/ecs/auto_scaling.tf

# Source: modules/ecs/ecs.tf

# Source: modules/ecs/ecs.tf
resource "aws_ecs_service" "ecs__service" {
  for_each = local.service_configs

  name        = "${var.ecs__name_prefix}-${each.key}"
  cluster     = aws_ecs_cluster.ecs__this.id
  launch_type = "FARGATE"
  # desired_count already reflects statefulness rules from local.service_configs.
  desired_count                      = each.value.desired_count
  task_definition                    = aws_ecs_task_definition.ecs__service[each.key].arn
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = var.ecs__use_codedeploy_controller ? null : 50
  deployment_maximum_percent         = var.ecs__use_codedeploy_controller ? null : 200

  # CODE_DEPLOY controller enables CodeDeploy blue/green deployments.
  # Default ECS controller uses rolling updates.
  dynamic "deployment_controller" {
    for_each = var.ecs__use_codedeploy_controller ? [1] : []
    content {
      type = "CODE_DEPLOY"
    }
  }

  # Circuit breaker for automatic rollback on failed deployments.
  # Only compatible with the default ECS (rolling-update) controller.
  dynamic "deployment_circuit_breaker" {
    for_each = var.ecs__use_codedeploy_controller ? [] : [1]
    content {
      enable   = true
      rollback = true
    }
  }

  # CloudWatch alarm-based deployment monitoring (complements circuit breaker).
  # Only compatible with the default ECS controller.
  dynamic "alarms" {
    for_each = !var.ecs__use_codedeploy_controller && var.ecs__enable_deployment_alarms && contains(keys(var.ecs__deployment_alarm_names), each.key) ? [1] : []
    content {
      alarm_names = var.ecs__deployment_alarm_names[each.key]
      enable      = true
      rollback    = true
    }
  }

  # Network configuration for Fargate tasks
  network_configuration {
    subnets          = var.ecs__service_subnet_ids
    security_groups  = [var.ecs__ecs_service_security_group_id]
    assign_public_ip = var.ecs__assign_public_ip
  }

  # Load balancer integration
  load_balancer {
    target_group_arn = var.ecs__target_group_arns[each.key]
    container_name   = each.key
    container_port   = 8080
  }

  # Service discovery registration (disabled when Cloud Map is not available)
  dynamic "service_registries" {
    for_each = var.ecs__enable_service_discovery ? [1] : []
    content {
      registry_arn   = aws_service_discovery_service.ecs__service[each.key].arn
      container_name = each.key
      container_port = 8080
    }
  }
}

# Source: modules/ecs/ecs.tf

# Source: modules/ecs/logs.tf

# Source: modules/ecs/main.tf
locals {
  # Services that require strict single-replica safety when stateful scale-out
  # is disabled. Toggle via enable_stateful_service_scale_out.
  in_memory_stateful_services = toset(["user", "transaction"])

  requested_desired_counts = {
    user        = var.ecs__desired_counts.user
    client      = var.ecs__desired_counts.client
    transaction = var.ecs__desired_counts.transaction
  }

  effective_desired_counts = merge(
    local.requested_desired_counts,
    var.ecs__enable_stateful_service_scale_out ? {} : {
      for service_name in local.in_memory_stateful_services : service_name => 1
    }
  )

  service_configs = {
    user = {
      desired_count = local.effective_desired_counts.user
      image_tag     = var.ecs__image_tags.user
      environment = [
        {
          name  = "ROOT_ADMIN_EMAIL"
          value = var.ecs__root_admin_email
        },
        {
          name  = "SPRING_DATASOURCE_URL"
          value = var.ecs__db_jdbc_url
        },
        {
          name  = "APP_USER_STORE_TYPE"
          value = "postgres"
        },
        {
          name  = "AUTH_MODE"
          value = var.ecs__auth_mode
        },
        {
          name  = "COGNITO_ISSUER"
          value = var.ecs__cognito_issuer_url
        },
        {
          name  = "COGNITO_JWKS_URL"
          value = var.ecs__cognito_jwks_url
        },
        {
          name  = "COGNITO_AUDIENCE"
          value = var.ecs__cognito_audience
        }
      ]
      secrets = [
        {
          name      = "ROOT_ADMIN_PASSWORD"
          valueFrom = var.ecs__root_admin_password_secret_arn
        },
        {
          name      = "JWT_HMAC_SECRET"
          valueFrom = var.ecs__jwt_hmac_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = var.ecs__db_username_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.ecs__db_password_secret_arn
        }
      ]
    }
    client = {
      desired_count = local.effective_desired_counts.client
      image_tag     = var.ecs__image_tags.client
      environment = [
        {
          name  = "SPRING_DATASOURCE_URL"
          value = var.ecs__db_jdbc_url
        },
        {
          name  = "CLIENT_LOG_SERVICE_URL"
          value = var.ecs__log_api_base_url
        },
        {
          name  = "VERIFICATION_EMAIL_PROVIDER"
          value = var.ecs__verification_email_provider
        },
        {
          name  = "SES_SENDER_EMAIL"
          value = var.ecs__ses_sender_email
        },
        {
          name  = "VERIFICATION_SNS_TOPIC_ARN"
          value = var.ecs__verification_sns_topic_arn
        },
        {
          name  = "VERIFICATION_DOCUMENTS_BUCKET"
          value = var.ecs__verification_documents_bucket
        },
        {
          name  = "VERIFICATION_EMAIL_AWS_REGION"
          value = var.ecs__aws_region
        },
        {
          name  = "AUTH_MODE"
          value = var.ecs__auth_mode
        },
        {
          name  = "COGNITO_ISSUER"
          value = var.ecs__cognito_issuer_url
        },
        {
          name  = "COGNITO_JWKS_URL"
          value = var.ecs__cognito_jwks_url
        },
        {
          name  = "COGNITO_AUDIENCE"
          value = var.ecs__cognito_audience
        }
      ]
      secrets = [
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = var.ecs__db_username_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.ecs__db_password_secret_arn
        },
        {
          name      = "JWT_HMAC_SECRET"
          valueFrom = var.ecs__jwt_hmac_secret_arn
        }
      ]
    }
    transaction = {
      desired_count = local.effective_desired_counts.transaction
      image_tag     = var.ecs__image_tags.transaction
      environment = [
        {
          name  = "CLIENT_SERVICE_URL"
          value = local.client_service_internal_url
        },
        {
          name  = "MOCK_SFTP_ROOT"
          value = var.ecs__transaction_mock_sftp_root
        },
        {
          name  = "SPRING_DATASOURCE_URL"
          value = var.ecs__db_jdbc_url
        },
        {
          name  = "APP_TRANSACTIONS_STORE_TYPE"
          value = "postgres"
        },
        {
          name  = "TRANSACTION_IMPORT_S3_BUCKET"
          value = var.ecs__transaction_import_s3_bucket
        },
        {
          name  = "TRANSACTION_IMPORT_S3_REGION"
          value = var.ecs__transaction_import_s3_region
        },
        {
          name  = "TRANSACTION_IMPORT_S3_ENDPOINT"
          value = var.ecs__transaction_import_s3_endpoint
        },
        {
          name  = "TRANSACTION_IMPORT_S3_PATH_STYLE_ACCESS_ENABLED"
          value = tostring(var.ecs__transaction_import_s3_path_style_access_enabled)
        },
        {
          name  = "AUTH_MODE"
          value = var.ecs__auth_mode
        },
        {
          name  = "COGNITO_ISSUER"
          value = var.ecs__cognito_issuer_url
        },
        {
          name  = "COGNITO_JWKS_URL"
          value = var.ecs__cognito_jwks_url
        },
        {
          name  = "COGNITO_AUDIENCE"
          value = var.ecs__cognito_audience
        }
      ]
      secrets = [
        {
          name      = "JWT_HMAC_SECRET"
          valueFrom = var.ecs__jwt_hmac_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = var.ecs__db_username_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.ecs__db_password_secret_arn
        }
      ]
    }
  }

  autoscaled_service_configs = {
    for service_name, config in local.service_configs :
    service_name => config
    if var.ecs__enable_stateful_service_scale_out || !contains(local.in_memory_stateful_services, service_name)
  }

  # CloudMap namespace for service discovery.
  # Derived from the resource attribute when discovery is on so that any change
  # to the namespace name propagates automatically rather than silently diverging.
  cloudmap_namespace_name     = var.ecs__enable_service_discovery ? aws_service_discovery_private_dns_namespace.ecs__internal[0].name : "${var.ecs__environment}.${var.ecs__project_name}.internal"
  client_service_internal_url = var.ecs__enable_service_discovery ? "http://client.${local.cloudmap_namespace_name}:8080" : "http://${var.ecs__alb_dns_name}"
}

# Source: modules/ecs/main.tf
resource "aws_ecs_cluster" "ecs__this" {
  name = "${var.ecs__name_prefix}-ecs"

  setting {
    name  = "containerInsights"
    value = var.ecs__enable_container_insights ? "enabled" : "disabled"
  }
}

# Source: modules/ecs/service_discovery.tf
resource "aws_service_discovery_private_dns_namespace" "ecs__internal" {
  count = var.ecs__enable_service_discovery ? 1 : 0

  name = "${var.ecs__environment}.${var.ecs__project_name}.internal"
  vpc  = var.ecs__vpc_id
}

# Source: modules/ecs/service_discovery.tf
resource "aws_service_discovery_service" "ecs__service" {
  for_each = var.ecs__enable_service_discovery ? local.service_configs : {}

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.ecs__internal[0].id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {}
}

# ---- Module: lambda ----
# Variables for module lambda
variable "lambda__aml_consumer_memory_size" {
  type    = any
  default = null
}

variable "lambda__aml_consumer_role_arn" {
  type    = any
  default = null
}

variable "lambda__aml_consumer_timeout_seconds" {
  type    = any
  default = null
}

variable "lambda__aml_consumer_zip_path" {
  type    = any
  default = null
}

variable "lambda__aml_dynamodb_table_name" {
  type    = any
  default = null
}

variable "lambda__aml_entity_id" {
  type    = any
  default = null
}

variable "lambda__aml_lambda_memory_size" {
  type    = any
  default = null
}

variable "lambda__aml_lambda_role_arn" {
  type    = any
  default = null
}

variable "lambda__aml_lambda_timeout_seconds" {
  type    = any
  default = null
}

variable "lambda__aml_lambda_zip_path" {
  type    = any
  default = null
}

variable "lambda__aml_schedule_expression" {
  type    = any
  default = null
}

variable "lambda__aml_sftp_host" {
  type    = any
  default = null
}

variable "lambda__aml_sftp_key_secret_arn" {
  type    = any
  default = null
}

variable "lambda__aml_sftp_port" {
  type    = any
  default = null
}

variable "lambda__aml_sftp_remote_path" {
  type    = any
  default = null
}

variable "lambda__aml_sftp_user" {
  type    = any
  default = null
}

variable "lambda__aml_sqs_arn" {
  type    = any
  default = null
}

variable "lambda__audit_consumer_memory_size" {
  type    = any
  default = null
}

variable "lambda__audit_consumer_role_arn" {
  type    = any
  default = null
}

variable "lambda__audit_consumer_timeout_seconds" {
  type    = any
  default = null
}

variable "lambda__audit_consumer_zip_path" {
  type    = any
  default = null
}

variable "lambda__audit_dynamodb_table_name" {
  type    = any
  default = null
}

variable "lambda__audit_sqs_arn" {
  type    = any
  default = null
}

variable "lambda__auth_mode" {
  type    = any
  default = "hybrid"
}

variable "lambda__cloudwatch_log_retention_days" {
  type    = any
  default = 30
}

variable "lambda__cognito_audience" {
  type    = any
  default = null
}

variable "lambda__cognito_issuer_url" {
  type    = any
  default = null
}

variable "lambda__cognito_jwks_url" {
  type    = any
  default = null
}

variable "lambda__crm_api_base_url" {
  type    = any
  default = null
}

variable "lambda__db_host" {
  type    = any
  default = null
}

variable "lambda__db_name" {
  type    = any
  default = null
}

variable "lambda__db_password_secret_arn" {
  type    = any
  default = null
}

variable "lambda__db_port" {
  type    = any
  default = null
}

variable "lambda__db_username_secret_arn" {
  type    = any
  default = null
}

variable "lambda__enable_aml_consumer" {
  type    = any
  default = null
}

variable "lambda__enable_aml_lambda" {
  type    = any
  default = false
}

variable "lambda__enable_audit_consumer" {
  type    = any
  default = null
}

variable "lambda__enable_log_lambda" {
  type    = any
  default = true
}

variable "lambda__enable_sftp_transaction_collector" {
  type    = any
  default = true
}

variable "lambda__enable_verification_lambda" {
  type    = any
  default = null
}

variable "lambda__environment" {
  type    = any
  default = "prod"
}

variable "lambda__jwt_hmac_secret_arn" {
  type    = any
  default = null
}

variable "lambda__lambda_security_group_id" {
  type    = any
  default = null
}

variable "lambda__log_api_base_url" {
  type    = any
  default = null
}

variable "lambda__log_lambda_memory_size" {
  type    = any
  default = null
}

variable "lambda__log_lambda_role_arn" {
  type    = any
  default = null
}

variable "lambda__log_lambda_timeout_seconds" {
  type    = any
  default = null
}

variable "lambda__log_lambda_zip_path" {
  type    = any
  default = null
}

variable "lambda__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "lambda__private_subnet_ids" {
  type    = any
  default = null
}

variable "lambda__project_name" {
  type    = any
  default = "scroogebank-crm"
}

variable "lambda__ses_sender_email" {
  type    = any
  default = "verification@crm.local"
}

variable "lambda__sftp_transaction_collector_memory_size" {
  type    = any
  default = null
}

variable "lambda__sftp_transaction_collector_role_arn" {
  type    = any
  default = null
}

variable "lambda__sftp_transaction_collector_schedule_expression" {
  type    = any
  default = null
}

variable "lambda__sftp_transaction_collector_timeout_seconds" {
  type    = any
  default = null
}

variable "lambda__sftp_transaction_collector_zip_path" {
  type    = any
  default = null
}

variable "lambda__transaction_import_api_url" {
  type    = any
  default = null
}

variable "lambda__transaction_sftp_bucket_id" {
  type    = any
  default = null
}

variable "lambda__transaction_sftp_remote_prefix" {
  type    = any
  default = null
}

variable "lambda__verification_frontend_base_url" {
  type    = any
  default = null
}

variable "lambda__verification_jwt_hmac_secret_arn" {
  type    = any
  default = null
}

variable "lambda__verification_memory_size" {
  type    = any
  default = null
}

variable "lambda__verification_role_arn" {
  type    = any
  default = null
}

variable "lambda__verification_sns_topic_arn" {
  type    = any
  default = null
}

variable "lambda__verification_timeout_seconds" {
  type    = any
  default = null
}

variable "lambda__verification_zip_path" {
  type    = any
  default = null
}

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

resource "aws_lambda_function" "lambda__log" {
  count = var.lambda__enable_log_lambda ? 1 : 0

  function_name    = "${var.lambda__name_prefix}-log-service"
  filename         = var.lambda__log_lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda__log_lambda_zip_path)
  role             = var.lambda__log_lambda_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.lambda__log_lambda_memory_size
  timeout          = var.lambda__log_lambda_timeout_seconds
  publish          = true

  vpc_config {
    subnet_ids         = var.lambda__private_subnet_ids
    security_group_ids = [var.lambda__lambda_security_group_id]
  }

  environment {
    variables = {
      DB_HOST                = var.lambda__db_host
      DB_PORT                = tostring(var.lambda__db_port)
      DB_NAME                = var.lambda__db_name
      DB_USER_SECRET_ARN     = var.lambda__db_username_secret_arn
      DB_PASSWORD_SECRET_ARN = var.lambda__db_password_secret_arn
      JWT_HMAC_SECRET_ARN    = var.lambda__jwt_hmac_secret_arn
      AUTH_MODE              = var.lambda__auth_mode
      COGNITO_ISSUER         = var.lambda__cognito_issuer_url
      COGNITO_JWKS_URL       = var.lambda__cognito_jwks_url
      COGNITO_CLIENT_ID      = var.lambda__cognito_audience
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda__log_lambda[0]]
}

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

resource "aws_lambda_function" "lambda__aml" {
  count = var.lambda__enable_aml_lambda ? 1 : 0

  function_name    = "${var.lambda__name_prefix}-aml"
  filename         = var.lambda__aml_lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda__aml_lambda_zip_path)
  role             = var.lambda__aml_lambda_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.lambda__aml_lambda_memory_size
  timeout          = var.lambda__aml_lambda_timeout_seconds
  publish          = true

  environment {
    variables = {
      SFTP_HOST                   = var.lambda__aml_sftp_host
      SFTP_PORT                   = tostring(var.lambda__aml_sftp_port)
      SFTP_USER                   = var.lambda__aml_sftp_user
      SFTP_KEY_SECRET             = var.lambda__aml_sftp_key_secret_arn
      SFTP_REMOTE_PATH            = var.lambda__aml_sftp_remote_path
      CRM_API_BASE_URL            = var.lambda__crm_api_base_url
      CRM_LOG_API_URL_PARAM       = "/${var.lambda__project_name}/${var.lambda__environment}/service/log/url"
      CRM_API_JWT_HMAC_SECRET_ARN = var.lambda__jwt_hmac_secret_arn
      JWT_HMAC_SECRET_ARN         = var.lambda__jwt_hmac_secret_arn
      ENTITY_ID                   = var.lambda__aml_entity_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda__aml_lambda[0]]
}

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

resource "aws_lambda_function" "lambda__sftp_transaction_collector" {
  count = var.lambda__enable_sftp_transaction_collector ? 1 : 0

  function_name    = "${var.lambda__name_prefix}-sftp-transaction-collector"
  filename         = var.lambda__sftp_transaction_collector_zip_path
  source_code_hash = filebase64sha256(var.lambda__sftp_transaction_collector_zip_path)
  role             = var.lambda__sftp_transaction_collector_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.lambda__sftp_transaction_collector_memory_size
  timeout          = var.lambda__sftp_transaction_collector_timeout_seconds
  publish          = true

  environment {
    variables = {
      # Legacy naming retained for compatibility; bucket/prefix are S3-backed mock ingestion inputs.
      TRANSACTION_SFTP_BUCKET                = var.lambda__transaction_sftp_bucket_id
      TRANSACTION_SFTP_PREFIX                = var.lambda__transaction_sftp_remote_prefix
      TRANSACTION_IMPORT_URL                 = var.lambda__transaction_import_api_url
      TRANSACTION_IMPORT_JWT_HMAC_SECRET_ARN = var.lambda__jwt_hmac_secret_arn
      JWT_HMAC_SECRET_ARN                    = var.lambda__jwt_hmac_secret_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda__sftp_transaction_collector[0]]
}

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

resource "aws_lambda_function" "lambda__audit_consumer" {
  count = var.lambda__enable_audit_consumer ? 1 : 0

  function_name    = "${var.lambda__name_prefix}-audit-consumer"
  filename         = var.lambda__audit_consumer_zip_path
  source_code_hash = filebase64sha256(var.lambda__audit_consumer_zip_path)
  role             = var.lambda__audit_consumer_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.lambda__audit_consumer_memory_size
  timeout          = var.lambda__audit_consumer_timeout_seconds

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.lambda__audit_dynamodb_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda__audit_consumer]
}

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

resource "aws_lambda_function" "lambda__aml_consumer" {
  count = var.lambda__enable_aml_consumer ? 1 : 0

  function_name    = "${var.lambda__name_prefix}-aml-consumer"
  filename         = var.lambda__aml_consumer_zip_path
  source_code_hash = filebase64sha256(var.lambda__aml_consumer_zip_path)
  role             = var.lambda__aml_consumer_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.lambda__aml_consumer_memory_size
  timeout          = var.lambda__aml_consumer_timeout_seconds

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.lambda__aml_dynamodb_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda__aml_consumer]
}

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

resource "aws_lambda_function" "lambda__verification" {
  count = var.lambda__enable_verification_lambda ? 1 : 0

  function_name    = "${var.lambda__name_prefix}-verification"
  filename         = var.lambda__verification_zip_path
  source_code_hash = filebase64sha256(var.lambda__verification_zip_path)
  role             = var.lambda__verification_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  memory_size      = var.lambda__verification_memory_size
  timeout          = var.lambda__verification_timeout_seconds
  publish          = true

  environment {
    variables = {
      SES_SOURCE_EMAIL                 = var.lambda__ses_sender_email
      FRONTEND_BASE_URL                = var.lambda__verification_frontend_base_url
      LOG_API_BASE_URL                 = var.lambda__log_api_base_url
      VERIFICATION_JWT_HMAC_SECRET_ARN = var.lambda__verification_jwt_hmac_secret_arn
      VERIFICATION_JWT_SUB             = "SYSTEM_VERIFICATION_FEEDBACK"
      VERIFICATION_JWT_ROLE            = "admin"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda__verification]
}

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# Source: modules/lambda/main.tf

# ---- Module: network ----
# Variables for module network
variable "network__az_count" {
  type    = any
  default = null
}

variable "network__db_subnet_cidrs" {
  type    = any
  default = null
}

variable "network__enable_multi_az_nat" {
  type    = any
  default = false
}

variable "network__enable_nat_gateway" {
  type    = any
  default = false
}

variable "network__enable_vpc_flow_logs" {
  type    = any
  default = false
}

variable "network__flow_log_retention_days" {
  type    = any
  default = null
}

variable "network__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "network__private_subnet_cidrs" {
  type    = any
  default = null
}

variable "network__public_subnet_cidrs" {
  type    = any
  default = null
}

variable "network__vpc_cidr" {
  type    = any
  default = null
}

# Source: modules/network/main.tf

# Source: modules/network/main.tf
locals {
  # Select the number of AZs specified by var.network__az_count
  selected_azs = slice(data.aws_availability_zones.network__available.names, 0, var.network__az_count)

  # Create subnet maps for for_each iteration
  public_subnet_map  = { for idx, cidr in var.network__public_subnet_cidrs : tostring(idx) => cidr }
  private_subnet_map = { for idx, cidr in var.network__private_subnet_cidrs : tostring(idx) => cidr }
  db_subnet_map      = { for idx, cidr in var.network__db_subnet_cidrs : tostring(idx) => cidr }
}

# Source: modules/network/route_tables.tf

# Source: modules/network/route_tables.tf

# Source: modules/network/route_tables.tf

# Source: modules/network/route_tables.tf

# Source: modules/network/route_tables.tf

# Source: modules/network/route_tables.tf

# Source: modules/network/route_tables.tf

# Source: modules/network/route_tables.tf

# Source: modules/network/subnets.tf
resource "aws_subnet" "network__public" {
  for_each = local.public_subnet_map

  vpc_id                  = aws_vpc.network__this.id
  cidr_block              = each.value
  availability_zone       = local.selected_azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.network__name_prefix}-public-${tonumber(each.key) + 1}"
    Tier = "public"
  }
}

# Source: modules/network/subnets.tf
resource "aws_subnet" "network__private" {
  for_each = local.private_subnet_map

  vpc_id            = aws_vpc.network__this.id
  cidr_block        = each.value
  availability_zone = local.selected_azs[tonumber(each.key)]

  tags = {
    Name = "${var.network__name_prefix}-private-${tonumber(each.key) + 1}"
    Tier = "private"
  }
}

# Source: modules/network/subnets.tf
resource "aws_subnet" "network__db" {
  for_each = local.db_subnet_map

  vpc_id            = aws_vpc.network__this.id
  cidr_block        = each.value
  availability_zone = local.selected_azs[tonumber(each.key)]

  tags = {
    Name = "${var.network__name_prefix}-db-${tonumber(each.key) + 1}"
    Tier = "database"
  }
}

# Source: modules/network/vpc.tf
resource "aws_vpc" "network__this" {
  cidr_block           = var.network__vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.network__name_prefix}-vpc"
  }
}

# Source: modules/network/vpc.tf
resource "aws_internet_gateway" "network__this" {
  vpc_id = aws_vpc.network__this.id

  tags = {
    Name = "${var.network__name_prefix}-igw"
  }
}

# Source: modules/network/vpc.tf

# Source: modules/network/vpc.tf
resource "aws_nat_gateway" "network__this" {
  count = var.network__enable_nat_gateway ? (var.network__enable_multi_az_nat ? var.network__az_count : 1) : 0

  allocation_id = aws_eip.network__nat[count.index].id
  subnet_id     = aws_subnet.network__public[tostring(count.index)].id

  tags = {
    Name = var.network__enable_multi_az_nat ? "${var.network__name_prefix}-nat-${count.index}" : "${var.network__name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.network__this]
}

# Source: modules/network/vpc_flow_logs.tf

# Source: modules/network/vpc_flow_logs.tf

# Source: modules/network/vpc_flow_logs.tf

# Source: modules/network/vpc_flow_logs.tf

# ---- Module: observability ----
# Variables for module observability
variable "observability__alarm_notification_topic_arn" {
  type    = any
  default = null
}

variable "observability__alb_5xx_alarm_threshold" {
  type    = any
  default = null
}

variable "observability__alb_arn_suffix" {
  type    = any
  default = null
}

variable "observability__alb_response_time_threshold" {
  type    = any
  default = null
}

variable "observability__alb_target_5xx_threshold" {
  type    = any
  default = null
}

variable "observability__alb_unhealthy_host_threshold" {
  type    = any
  default = null
}

variable "observability__aws_region" {
  type    = any
  default = "ap-southeast-1"
}

variable "observability__cloudtrail_bucket_force_destroy" {
  type    = any
  default = null
}

variable "observability__ecs_cluster_name" {
  type    = any
  default = null
}

variable "observability__ecs_cpu_alarm_threshold" {
  type    = any
  default = null
}

variable "observability__ecs_memory_alarm_threshold" {
  type    = any
  default = null
}

variable "observability__ecs_service_names" {
  type    = any
  default = null
}

variable "observability__enable_alb_alarms" {
  type    = any
  default = null
}

variable "observability__enable_cloudtrail" {
  type    = any
  default = false
}

variable "observability__enable_dashboard" {
  type    = any
  default = null
}

variable "observability__enable_ecs_alarms" {
  type    = any
  default = null
}

variable "observability__enable_rds_alarms" {
  type    = any
  default = null
}

variable "observability__enable_ses_alarms" {
  type    = any
  default = null
}

variable "observability__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "observability__rds_cpu_alarm_threshold" {
  type    = any
  default = null
}

variable "observability__rds_free_storage_threshold_bytes" {
  type    = any
  default = null
}

variable "observability__rds_instance_identifier" {
  type    = any
  default = null
}

variable "observability__ses_bounce_rate_alarm_threshold" {
  type    = any
  default = null
}

variable "observability__ses_complaint_rate_alarm_threshold" {
  type    = any
  default = null
}

variable "observability__ses_identity" {
  type    = any
  default = null
}

variable "observability__target_group_arn_suffixes" {
  type    = any
  default = null
}

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

locals {
  alarm_action_arns = trimspace(var.observability__alarm_notification_topic_arn) == "" ? [] : [trimspace(var.observability__alarm_notification_topic_arn)]
}

# Source: modules/observability/main.tf

resource "aws_s3_bucket" "observability__cloudtrail" {
  count = var.observability__enable_cloudtrail ? 1 : 0

  bucket        = "${var.observability__name_prefix}-cloudtrail-${data.aws_caller_identity.observability__current.account_id}"
  force_destroy = var.observability__cloudtrail_bucket_force_destroy

  tags = {
    Name = "${var.observability__name_prefix}-cloudtrail"
  }
}

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

resource "aws_cloudtrail" "observability__this" {
  count = var.observability__enable_cloudtrail ? 1 : 0

  name                          = "${var.observability__name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.observability__cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  tags = {
    Name = "${var.observability__name_prefix}-trail"
  }

  depends_on = [aws_s3_bucket_policy.observability__cloudtrail]
}

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# Source: modules/observability/main.tf

# ---- Module: rds ----
# Variables for module rds
variable "rds__db_allocated_storage" {
  type    = any
  default = null
}

variable "rds__db_backup_retention_days" {
  type    = any
  default = 1
}

variable "rds__db_deletion_protection" {
  type    = any
  default = false
}

variable "rds__db_engine_version" {
  type    = any
  default = null
}

variable "rds__db_instance_class" {
  type    = any
  default = "db.t4g.micro"
}

variable "rds__db_max_allocated_storage" {
  type    = any
  default = 20
}

variable "rds__db_multi_az" {
  type    = any
  default = false
}

variable "rds__db_name" {
  type    = any
  default = null
}

variable "rds__db_parameter_group_family" {
  type    = any
  default = null
}

variable "rds__db_password_value" {
  type    = any
  default = null
}

variable "rds__db_port" {
  type    = any
  default = null
}

variable "rds__db_security_group_id" {
  type    = any
  default = null
}

variable "rds__db_skip_final_snapshot" {
  type    = any
  default = true
}

variable "rds__db_username" {
  type    = any
  default = null
}

variable "rds__environment" {
  type    = any
  default = "prod"
}

variable "rds__iam_database_authentication_enabled" {
  type    = any
  default = null
}

variable "rds__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "rds__performance_insights_enabled" {
  type    = any
  default = null
}

variable "rds__private_subnet_ids" {
  type    = any
  default = null
}

variable "rds__project_name" {
  type    = any
  default = "scroogebank-crm"
}

# Source: modules/rds/kms.tf

# Source: modules/rds/kms.tf

# Source: modules/rds/main.tf

locals {
  db_jdbc_url = "jdbc:postgresql://${aws_db_instance.rds__postgres.address}:${var.rds__db_port}/${var.rds__db_name}"
}

# Source: modules/rds/main.tf

resource "aws_db_subnet_group" "rds__postgres" {
  name       = "${var.rds__name_prefix}-db-subnets"
  subnet_ids = var.rds__private_subnet_ids

  tags = {
    Name = "${var.rds__name_prefix}-db-subnets"
  }
}

# Source: modules/rds/main.tf

# Source: modules/rds/main.tf

resource "aws_db_instance" "rds__postgres" {
  identifier                 = "${var.rds__name_prefix}-postgres"
  engine                     = "postgres"
  engine_version             = var.rds__db_engine_version != "" ? var.rds__db_engine_version : null
  instance_class             = var.rds__db_instance_class
  allocated_storage          = var.rds__db_allocated_storage
  max_allocated_storage      = var.rds__db_max_allocated_storage
  storage_type               = "gp3"
  storage_encrypted          = true
  kms_key_id                 = aws_kms_key.rds__rds.arn
  db_name                    = var.rds__db_name
  username                   = var.rds__db_username
  password                   = var.rds__db_password_value
  port                       = var.rds__db_port
  parameter_group_name       = aws_db_parameter_group.rds__postgres.name
  db_subnet_group_name       = aws_db_subnet_group.rds__postgres.name
  vpc_security_group_ids     = [var.rds__db_security_group_id]
  backup_retention_period    = var.rds__db_backup_retention_days
  multi_az                   = var.rds__db_multi_az
  skip_final_snapshot        = var.rds__db_skip_final_snapshot
  final_snapshot_identifier  = var.rds__db_skip_final_snapshot ? null : "${var.rds__name_prefix}-postgres-final"
  deletion_protection        = var.rds__db_deletion_protection
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  apply_immediately          = true

  performance_insights_enabled          = var.rds__performance_insights_enabled
  performance_insights_kms_key_id       = var.rds__performance_insights_enabled ? aws_kms_key.rds__rds.arn : null
  performance_insights_retention_period = var.rds__performance_insights_enabled ? 7 : null

  iam_database_authentication_enabled = var.rds__iam_database_authentication_enabled
}

# Source: modules/rds/main.tf

# Source: modules/rds/main.tf

# Source: modules/rds/main.tf

# Source: modules/rds/main.tf

# ---- Module: s3 ----
# Variables for module s3
variable "s3__enable_transaction_sftp_bucket" {
  type    = any
  default = null
}

variable "s3__enable_verification_bucket" {
  type    = any
  default = null
}

variable "s3__frontend_bucket_allow_public" {
  type    = any
  default = null
}

variable "s3__frontend_bucket_force_destroy" {
  type    = any
  default = false
}

variable "s3__frontend_bucket_name" {
  type    = any
  default = null
}

variable "s3__transaction_sftp_bucket_name" {
  type    = any
  default = null
}

variable "s3__verification_bucket_name" {
  type    = any
  default = null
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket" "s3__frontend" {
  bucket        = var.s3__frontend_bucket_name
  force_destroy = var.s3__frontend_bucket_force_destroy
}

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

resource "aws_s3_bucket" "s3__verification" {
  count = var.s3__enable_verification_bucket ? 1 : 0

  bucket        = var.s3__verification_bucket_name
  force_destroy = false

  tags = {
    Name = var.s3__verification_bucket_name
  }
}

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

resource "aws_s3_bucket" "s3__transaction_sftp" {
  count = var.s3__enable_transaction_sftp_bucket ? 1 : 0

  bucket        = var.s3__transaction_sftp_bucket_name
  force_destroy = false

  tags = {
    Name = var.s3__transaction_sftp_bucket_name
  }
}

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# Source: modules/s3/main.tf

# ---- Module: security ----
# Variables for module security
variable "security__aml_dlq_arn" {
  type    = any
  default = null
}

variable "security__aml_dynamodb_table_arn" {
  type    = any
  default = null
}

variable "security__aml_sftp_key_secret_arn" {
  type    = any
  default = null
}

variable "security__aml_sqs_arn" {
  type    = any
  default = null
}

variable "security__audit_dlq_arn" {
  type    = any
  default = null
}

variable "security__audit_dynamodb_table_arn" {
  type    = any
  default = null
}

variable "security__audit_sqs_arn" {
  type    = any
  default = null
}

variable "security__aws_region" {
  type    = any
  default = "ap-southeast-1"
}

variable "security__backend_lock_table_name" {
  type    = any
  default = null
}

variable "security__backend_state_bucket_name" {
  type    = any
  default = null
}

variable "security__create_backend_iam_policy" {
  type    = any
  default = null
}

variable "security__db_port" {
  type    = any
  default = null
}

variable "security__db_username" {
  type    = any
  default = null
}

variable "security__enable_aml_pipeline" {
  type    = any
  default = false
}

variable "security__enable_audit_pipeline" {
  type    = any
  default = false
}

variable "security__enable_sftp_transaction_collector" {
  type    = any
  default = true
}

variable "security__enable_verification_pipeline" {
  type    = any
  default = true
}

variable "security__environment" {
  type    = any
  default = "prod"
}

variable "security__jwt_hmac_secret" {
  type    = any
  default = null
}

variable "security__lab_role_arn" {
  type    = any
  default = ""
}

variable "security__lab_role_name" {
  type    = any
  default = ""
}

variable "security__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "security__project_name" {
  type    = any
  default = "scroogebank-crm"
}

variable "security__root_admin_password" {
  type    = any
  default = null
}

variable "security__transaction_sftp_bucket_arn" {
  type    = any
  default = null
}

variable "security__verification_bucket_arn" {
  type    = any
  default = null
}

variable "security__verification_sns_topic_arn" {
  type    = any
  default = null
}

variable "security__vpc_id" {
  type    = any
  default = null
}

# Source: modules/security/main.tf

# Source: modules/security/main.tf

locals {
  # When a lab role override is supplied, skip all IAM role creation and use the
  # pre-existing role (for example, LabRole in Learner Lab which blocks iam:CreateRole).
  effective_lab_role_arn = var.security__lab_role_arn != "" ? var.security__lab_role_arn : (var.security__lab_role_name != "" ? "arn:aws:iam::${data.aws_caller_identity.security__current.account_id}:role/${var.security__lab_role_name}" : "")
  use_lab_role           = local.effective_lab_role_arn != ""
}

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/main.tf

# Source: modules/security/secrets.tf
locals {
  jwt_hmac_secret_value     = var.security__jwt_hmac_secret != "" ? var.security__jwt_hmac_secret : "brainboard-placeholder"
  root_admin_password_value = var.security__root_admin_password != "" ? var.security__root_admin_password : "brainboard-placeholder"
  db_password_value         = "brainboard-placeholder"
}

# Source: modules/security/secrets.tf

# Source: modules/security/secrets.tf

# Source: modules/security/secrets.tf

# Source: modules/security/secrets.tf

# Source: modules/security/secrets.tf

# Source: modules/security/secrets.tf

# Source: modules/security/secrets.tf

# Source: modules/security/secrets.tf

# ---- Module: ses ----
# Variables for module ses
variable "ses__domain" {
  type    = any
  default = null
}

variable "ses__enable_ses" {
  type    = any
  default = null
}

variable "ses__mail_from_subdomain" {
  type    = any
  default = null
}

variable "ses__notification_topic_arn" {
  type    = any
  default = null
}

variable "ses__sender_email" {
  type    = any
  default = null
}

# Source: modules/ses/main.tf
locals {
  notification_identity = var.ses__domain != "" ? var.ses__domain : var.ses__sender_email
}

# Source: modules/ses/main.tf
resource "aws_ses_email_identity" "ses__verification" {
  count = var.ses__enable_ses && var.ses__sender_email != "" && var.ses__domain == "" ? 1 : 0

  email = var.ses__sender_email
}

# Source: modules/ses/main.tf

# Source: modules/ses/main.tf

# Source: modules/ses/main.tf

# Source: modules/ses/main.tf

# ---- Module: sns ----
# Variables for module sns
variable "sns__alarm_notification_email" {
  type    = any
  default = "crm-alerts-prod@crm.local"
}

variable "sns__enable_alarm_topic" {
  type    = any
  default = null
}

variable "sns__enable_verification_pipeline" {
  type    = any
  default = true
}

variable "sns__environment" {
  type    = any
  default = "prod"
}

variable "sns__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

variable "sns__notification_email" {
  type    = any
  default = null
}

# Source: modules/sns/main.tf
resource "aws_sns_topic" "sns__verification" {
  count = var.sns__enable_verification_pipeline ? 1 : 0

  name = "${var.sns__name_prefix}-verification"

  tags = {
    Name        = "${var.sns__name_prefix}-verification"
    Environment = var.sns__environment
    Service     = "verification"
    ManagedBy   = "terraform"
  }
}

# Source: modules/sns/main.tf

# Source: modules/sns/main.tf
resource "aws_sns_topic" "sns__alarm_notifications" {
  count = var.sns__enable_alarm_topic ? 1 : 0

  name = "${var.sns__name_prefix}-alarms"

  tags = {
    Name        = "${var.sns__name_prefix}-alarms"
    Environment = var.sns__environment
    Service     = "observability"
    ManagedBy   = "terraform"
  }
}

# Source: modules/sns/main.tf

# ---- Module: sqs ----
# Variables for module sqs
variable "sqs__aml_visibility_timeout" {
  type    = any
  default = null
}

variable "sqs__audit_visibility_timeout" {
  type    = any
  default = null
}

variable "sqs__dlq_retention_seconds" {
  type    = any
  default = null
}

variable "sqs__enable_aml_pipeline" {
  type    = any
  default = false
}

variable "sqs__enable_audit_pipeline" {
  type    = any
  default = false
}

variable "sqs__environment" {
  type    = any
  default = "prod"
}

variable "sqs__max_receive_count" {
  type    = any
  default = null
}

variable "sqs__message_retention_seconds" {
  type    = any
  default = null
}

variable "sqs__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}

# Source: modules/sqs/main.tf
resource "aws_sqs_queue" "sqs__audit_dlq" {
  count = var.sqs__enable_audit_pipeline ? 1 : 0

  name                      = "${var.sqs__name_prefix}-audit-dlq"
  message_retention_seconds = var.sqs__dlq_retention_seconds

  tags = {
    Name        = "${var.sqs__name_prefix}-audit-dlq"
    Environment = var.sqs__environment
    Service     = "audit"
    ManagedBy   = "terraform"
  }
}

# Source: modules/sqs/main.tf
resource "aws_sqs_queue" "sqs__audit" {
  count = var.sqs__enable_audit_pipeline ? 1 : 0

  name                       = "${var.sqs__name_prefix}-audit-queue"
  visibility_timeout_seconds = var.sqs__audit_visibility_timeout
  message_retention_seconds  = var.sqs__message_retention_seconds
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sqs__audit_dlq[0].arn
    maxReceiveCount     = var.sqs__max_receive_count
  })

  tags = {
    Name        = "${var.sqs__name_prefix}-audit-queue"
    Environment = var.sqs__environment
    Service     = "audit"
    ManagedBy   = "terraform"
  }
}

# Source: modules/sqs/main.tf
resource "aws_sqs_queue" "sqs__aml_dlq" {
  count = var.sqs__enable_aml_pipeline ? 1 : 0

  name                      = "${var.sqs__name_prefix}-aml-dlq"
  message_retention_seconds = var.sqs__dlq_retention_seconds

  tags = {
    Name        = "${var.sqs__name_prefix}-aml-dlq"
    Environment = var.sqs__environment
    Service     = "aml"
    ManagedBy   = "terraform"
  }
}

# Source: modules/sqs/main.tf
resource "aws_sqs_queue" "sqs__aml" {
  count = var.sqs__enable_aml_pipeline ? 1 : 0

  name                       = "${var.sqs__name_prefix}-aml-queue"
  visibility_timeout_seconds = var.sqs__aml_visibility_timeout
  message_retention_seconds  = var.sqs__message_retention_seconds
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sqs__aml_dlq[0].arn
    maxReceiveCount     = var.sqs__max_receive_count
  })

  tags = {
    Name        = "${var.sqs__name_prefix}-aml-queue"
    Environment = var.sqs__environment
    Service     = "aml"
    ManagedBy   = "terraform"
  }
}

# ---- Module: waf ----
# Variables for module waf
variable "waf__enable_waf" {
  type    = any
  default = false
}

variable "waf__name_prefix" {
  type    = any
  default = "scroogebank-crm-prod"
}
