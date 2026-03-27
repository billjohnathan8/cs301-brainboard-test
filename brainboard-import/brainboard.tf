# Auto-generated Brainboard import file
# Source: modules/*
# Purpose: visualize resources (not intended for Terraform apply)
# Note: known Brainboard-unsupported resources are omitted.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" {
  region = "ap-southeast-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
}

provider "aws" {
  alias  = "ap_southeast_1"
  region = "ap-southeast-1"
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
  default = null
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
  default = null
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

resource "aws_lb_target_group" "alb__service" {
  for_each = local.service_routing

  name        = trim(substr("${var.alb__name_prefix}-${each.key}-tg", 0, 32), "-")
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.alb__vpc_id

  health_check {
    path                = var.alb__service_health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Source: modules/alb/main.tf

resource "aws_lb_target_group" "alb__service_green" {
  for_each = var.alb__enable_blue_green_tg ? local.service_routing : {}

  name        = trim(substr("${var.alb__name_prefix}-${each.key}-tg-green", 0, 32), "-")
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.alb__vpc_id

  health_check {
    path                = var.alb__service_health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Source: modules/alb/main.tf

resource "aws_lb_listener" "alb__http" {
  load_balancer_arn = aws_lb.alb__crm.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.alb__use_custom_domain ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.alb__use_custom_domain ? [] : [1]
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "application/json"
        message_body = "{\"message\":\"Not Found\"}"
        status_code  = "404"
      }
    }
  }
}

# Source: modules/alb/main.tf

resource "aws_lb_listener" "alb__https" {
  count = var.alb__use_custom_domain ? 1 : 0

  load_balancer_arn = aws_lb.alb__crm.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb__alb_certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"message\":\"Not Found\"}"
      status_code  = "404"
    }
  }
}

# Source: modules/alb/main.tf
resource "aws_lb_listener_rule" "alb__client_transactions" {
  listener_arn = var.alb__use_custom_domain ? aws_lb_listener.alb__https[0].arn : aws_lb_listener.alb__http.arn
  priority     = 15

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb__service["transaction"].arn
  }

  condition {
    path_pattern {
      values = ["/api/clients/*/transactions*"]
    }
  }
}

# Source: modules/alb/main.tf

resource "aws_lb_listener_rule" "alb__service" {
  for_each = local.service_routing

  listener_arn = var.alb__use_custom_domain ? aws_lb_listener.alb__https[0].arn : aws_lb_listener.alb__http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb__service[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}

# Source: modules/alb/route53.tf

resource "aws_route53_record" "alb__alb" {
  count = var.alb__manage_route53_record && var.alb__use_custom_domain && var.alb__route53_zone_id != "" ? 1 : 0

  zone_id = var.alb__route53_zone_id
  name    = var.alb__alb_subdomain
  type    = "A"

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
  default = null
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

resource "aws_apigatewayv2_integration" "apigateway__log_lambda" {
  api_id                 = aws_apigatewayv2_api.apigateway__log.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.apigateway__log_lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

# Source: modules/apigateway/main.tf

resource "aws_apigatewayv2_route" "apigateway__log" {
  for_each = local.log_api_route_keys

  api_id    = aws_apigatewayv2_api.apigateway__log.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.apigateway__log_lambda.id}"
}

# Source: modules/apigateway/main.tf

resource "aws_cloudwatch_log_group" "apigateway__api_gateway" {
  name              = "/aws/apigateway/${var.apigateway__name_prefix}-log-http-api"
  retention_in_days = var.apigateway__cloudwatch_log_retention_days
}

# Source: modules/apigateway/main.tf

resource "aws_apigatewayv2_stage" "apigateway__log_default" {
  api_id      = aws_apigatewayv2_api.apigateway__log.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway__api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      sourceIp         = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

# Source: modules/apigateway/main.tf

resource "aws_lambda_permission" "apigateway__allow_api_gateway_invoke_log" {
  statement_id  = "AllowExecutionFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = var.apigateway__log_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.apigateway__log.execution_arn}/*/*"
}

# Source: modules/apigateway/main.tf

resource "aws_ssm_parameter" "apigateway__log_service_url" {
  name  = "/${var.apigateway__project_name}/${var.apigateway__environment}/service/log/url"
  type  = "String"
  value = aws_apigatewayv2_api.apigateway__log.api_endpoint
}

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

resource "aws_iam_role" "backup__backup" {
  count = var.backup__enable_backup ? 1 : 0

  name = "${var.backup__name_prefix}-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Source: modules/backup/main.tf

resource "aws_iam_role_policy_attachment" "backup__backup" {
  count = var.backup__enable_backup ? 1 : 0

  role       = aws_iam_role.backup__backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Source: modules/backup/main.tf

resource "aws_iam_role_policy_attachment" "backup__backup_restore" {
  count = var.backup__enable_backup ? 1 : 0

  role       = aws_iam_role.backup__backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Source: modules/backup/main.tf

resource "aws_backup_selection" "backup__rds" {
  count = var.backup__enable_backup && var.backup__rds_instance_arn != "" ? 1 : 0

  name         = "${var.backup__name_prefix}-rds"
  plan_id      = aws_backup_plan.backup__this[0].id
  iam_role_arn = aws_iam_role.backup__backup[0].arn

  resources = [var.backup__rds_instance_arn]
}

# Source: modules/backup/main.tf

resource "aws_backup_selection" "backup__dynamodb" {
  count = var.backup__enable_backup && length(var.backup__dynamodb_table_arns) > 0 ? 1 : 0

  name         = "${var.backup__name_prefix}-dynamodb"
  plan_id      = aws_backup_plan.backup__this[0].id
  iam_role_arn = aws_iam_role.backup__backup[0].arn

  resources = var.backup__dynamodb_table_arns
}

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
  default = null
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
  default = null
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
  default = null
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
      origin_access_identity = ""
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

data "aws_iam_policy_document" "cloudfront__frontend_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:GetObject"]
    resources = [
      "${var.cloudfront__frontend_bucket_arn}/*",
    ]

    # OAC signs requests so S3 can verify SourceArn. Without OAC (Learner Lab),
    # CloudFront doesn't sign requests so this condition must be omitted.
    dynamic "condition" {
      for_each = var.cloudfront__enable_cloudfront_oac ? [1] : []
      content {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [aws_cloudfront_distribution.cloudfront__frontend.arn]
      }
    }
  }
}

# Source: modules/cloudfront/main.tf

resource "aws_s3_bucket_policy" "cloudfront__frontend" {
  bucket = var.cloudfront__frontend_bucket_id
  policy = data.aws_iam_policy_document.cloudfront__frontend_bucket_policy.json
}

# Source: modules/cloudfront/route53.tf

resource "aws_route53_record" "cloudfront__cloudfront" {
  count = var.cloudfront__manage_route53_record && var.cloudfront__use_custom_domain && var.cloudfront__route53_zone_id != "" ? 1 : 0

  zone_id = var.cloudfront__route53_zone_id
  name    = var.cloudfront__app_domain_name
  type    = "A"

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

resource "aws_iam_role" "codedeploy__codedeploy" {
  count = var.codedeploy__enable_codedeploy ? 1 : 0

  name = "${var.codedeploy__name_prefix}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Source: modules/codedeploy/main.tf

resource "aws_iam_role_policy_attachment" "codedeploy__codedeploy_ecs" {
  count = var.codedeploy__enable_codedeploy ? 1 : 0

  role       = aws_iam_role.codedeploy__codedeploy[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# Source: modules/codedeploy/main.tf

resource "aws_iam_role_policy_attachment" "codedeploy__codedeploy_lambda" {
  count = var.codedeploy__enable_codedeploy ? 1 : 0

  role       = aws_iam_role.codedeploy__codedeploy[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

# Source: modules/codedeploy/main.tf

resource "aws_codedeploy_app" "codedeploy__ecs" {
  count = var.codedeploy__enable_codedeploy ? 1 : 0

  name             = "${var.codedeploy__name_prefix}-ecs"
  compute_platform = "ECS"
}

# Source: modules/codedeploy/main.tf

resource "aws_codedeploy_deployment_group" "codedeploy__ecs" {
  for_each = var.codedeploy__enable_codedeploy ? var.codedeploy__ecs_service_names : {}

  app_name               = aws_codedeploy_app.codedeploy__ecs[0].name
  deployment_group_name  = "${var.codedeploy__name_prefix}-${each.key}-ecs"
  service_role_arn       = aws_iam_role.codedeploy__codedeploy[0].arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM", "DEPLOYMENT_STOP_ON_REQUEST"]
  }

  ecs_service {
    cluster_name = var.codedeploy__ecs_cluster_name
    service_name = each.value
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.codedeploy__alb_listener_arn]
      }

      target_group {
        name = var.codedeploy__ecs_blue_target_group_names[each.key]
      }

      target_group {
        name = var.codedeploy__ecs_green_target_group_names[each.key]
      }
    }
  }
}

# Source: modules/codedeploy/main.tf

resource "aws_codedeploy_app" "codedeploy__lambda" {
  count = var.codedeploy__enable_codedeploy ? 1 : 0

  name             = "${var.codedeploy__name_prefix}-lambda"
  compute_platform = "Lambda"
}

# Source: modules/codedeploy/main.tf

resource "aws_codedeploy_deployment_group" "codedeploy__lambda" {
  for_each = var.codedeploy__enable_codedeploy ? local.lambda_enabled_deployments : {}

  app_name               = aws_codedeploy_app.codedeploy__lambda[0].name
  deployment_group_name  = "${var.codedeploy__name_prefix}-${each.key}-lambda"
  service_role_arn       = aws_iam_role.codedeploy__codedeploy[0].arn
  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM", "DEPLOYMENT_STOP_ON_REQUEST"]
  }
}

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

resource "aws_cognito_user_group" "cognito__admin" {
  user_pool_id = aws_cognito_user_pool.cognito__this.id
  name         = "ADMIN"
  precedence   = 0
  description  = "Administrator group with highest privileges."
}

# Source: modules/cognito/main.tf

resource "aws_cognito_user_group" "cognito__user" {
  user_pool_id = aws_cognito_user_pool.cognito__this.id
  name         = "USER"
  precedence   = 1
  description  = "User group with standard CRM access."
}

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

resource "aws_cognito_user_pool_domain" "cognito__this" {
  count = var.cognito__cognito_domain_prefix != "" ? 1 : 0

  domain       = var.cognito__cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.cognito__this.id
}

# ---- Module: dynamodb ----
# Variables for module dynamodb
variable "dynamodb__billing_mode" {
  type    = any
  default = null
}

variable "dynamodb__enable_aml_table" {
  type    = any
  default = null
}

variable "dynamodb__enable_audit_table" {
  type    = any
  default = null
}

variable "dynamodb__enable_point_in_time_recovery" {
  type    = any
  default = null
}

variable "dynamodb__enable_ttl" {
  type    = any
  default = null
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
    key_schema {
      attribute_name = "user_id"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "sk"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "client-index"
    projection_type = "ALL"
    key_schema {
      attribute_name = "client_id"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "sk"
      key_type       = "RANGE"
    }
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
    key_schema {
      attribute_name = "entity_id"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "sk"
      key_type       = "RANGE"
    }
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

resource "aws_ecr_lifecycle_policy" "ecr__service" {
  for_each = aws_ecr_repository.ecr__service

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain latest 100 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 100
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

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
resource "aws_appautoscaling_target" "ecs__service" {
  for_each = local.autoscaled_service_configs

  max_capacity       = var.ecs__ecs_max_capacity
  min_capacity       = var.ecs__ecs_min_capacity
  resource_id        = "service/${aws_ecs_cluster.ecs__this.name}/${aws_ecs_service.ecs__service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Source: modules/ecs/auto_scaling.tf
resource "aws_appautoscaling_policy" "ecs__cpu" {
  for_each = local.autoscaled_service_configs

  name               = "${var.ecs__name_prefix}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs__service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs__service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs__service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.ecs__ecs_target_cpu_utilization
  }
}

# Source: modules/ecs/auto_scaling.tf
resource "aws_appautoscaling_policy" "ecs__memory" {
  for_each = local.autoscaled_service_configs

  name               = "${var.ecs__name_prefix}-${each.key}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs__service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs__service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs__service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.ecs__ecs_target_memory_utilization
  }
}

# Source: modules/ecs/ecs.tf
resource "aws_ecs_task_definition" "ecs__service" {
  for_each = local.service_configs

  family                   = "${var.ecs__name_prefix}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.ecs__ecs_task_cpu)
  memory                   = tostring(var.ecs__ecs_task_memory)
  execution_role_arn       = var.ecs__ecs_task_execution_role_arn
  task_role_arn            = var.ecs__ecs_task_role_arns[each.key]

  container_definitions = templatefile(local.task_definition_template, {
    container_name    = each.key
    image             = "${var.ecs__ecr_repository_urls[each.key]}:${each.value.image_tag}"
    container_port    = 8080
    environment_json  = jsonencode(each.value.environment)
    secrets_json      = jsonencode(each.value.secrets)
    log_group_name    = aws_cloudwatch_log_group.ecs__ecs[each.key].name
    aws_region        = var.ecs__aws_region
    healthcheck_cmd   = "wget -qO- http://localhost:8080${var.ecs__service_health_check_path} || exit 1"
    health_interval   = 30
    health_timeout    = 5
    health_retries    = 3
    health_start_time = 30
  })
}

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
resource "aws_ssm_parameter" "ecs__client_service_url" {
  name  = "/${var.ecs__project_name}/${var.ecs__environment}/service/client/internal_url"
  type  = "String"
  value = local.client_service_internal_url

  lifecycle {
    precondition {
      condition     = var.ecs__enable_service_discovery || var.ecs__alb_dns_name != ""
      error_message = "alb_dns_name must be provided when enable_service_discovery is false; CLIENT_SERVICE_URL would otherwise be empty."
    }
  }
}

# Source: modules/ecs/logs.tf
resource "aws_cloudwatch_log_group" "ecs__ecs" {
  for_each = local.service_configs

  name              = "/aws/ecs/${var.ecs__name_prefix}/${each.key}"
  retention_in_days = var.ecs__cloudwatch_log_retention_days

  tags = {
    Name        = "${var.ecs__name_prefix}-${each.key}-logs"
    Service     = each.key
    Environment = var.ecs__environment
  }
}

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
  task_definition_template    = "${path.module}/../template/ecs_json.tpl"
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

resource "aws_cloudwatch_log_group" "lambda__log_lambda" {
  count = var.lambda__enable_log_lambda ? 1 : 0

  name              = "/aws/lambda/${var.lambda__name_prefix}-log-service"
  retention_in_days = var.lambda__cloudwatch_log_retention_days
}

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

resource "aws_cloudwatch_log_group" "lambda__aml_lambda" {
  count = var.lambda__enable_aml_lambda ? 1 : 0

  name              = "/aws/lambda/${var.lambda__name_prefix}-aml"
  retention_in_days = var.lambda__cloudwatch_log_retention_days
}

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

resource "aws_cloudwatch_event_rule" "lambda__aml_schedule" {
  count = var.lambda__enable_aml_lambda ? 1 : 0

  name                = "${var.lambda__name_prefix}-aml-schedule"
  description         = "Schedule for AML Lambda batch processing."
  schedule_expression = var.lambda__aml_schedule_expression
  state               = "ENABLED"
}

# Source: modules/lambda/main.tf

resource "aws_cloudwatch_event_target" "lambda__aml_lambda" {
  count = var.lambda__enable_aml_lambda ? 1 : 0

  rule      = aws_cloudwatch_event_rule.lambda__aml_schedule[0].name
  target_id = "aml-lambda"
  arn       = aws_lambda_function.lambda__aml[0].arn
  input     = "{}"
}

# Source: modules/lambda/main.tf

resource "aws_lambda_permission" "lambda__allow_eventbridge_invoke_aml" {
  count = var.lambda__enable_aml_lambda ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda__aml[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda__aml_schedule[0].arn
}

# Source: modules/lambda/main.tf

resource "aws_cloudwatch_log_group" "lambda__sftp_transaction_collector" {
  count = var.lambda__enable_sftp_transaction_collector ? 1 : 0

  name              = "/aws/lambda/${var.lambda__name_prefix}-sftp-transaction-collector"
  retention_in_days = var.lambda__cloudwatch_log_retention_days
}

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

resource "aws_cloudwatch_event_rule" "lambda__sftp_transaction_collector_schedule" {
  count = var.lambda__enable_sftp_transaction_collector ? 1 : 0

  name                = "${var.lambda__name_prefix}-sftp-transaction-collector-schedule"
  description         = "Schedule for sftp-transaction-collector Lambda."
  schedule_expression = var.lambda__sftp_transaction_collector_schedule_expression
  state               = "ENABLED"
}

# Source: modules/lambda/main.tf

resource "aws_cloudwatch_event_target" "lambda__sftp_transaction_collector" {
  count = var.lambda__enable_sftp_transaction_collector ? 1 : 0

  rule      = aws_cloudwatch_event_rule.lambda__sftp_transaction_collector_schedule[0].name
  target_id = "sftp-transaction-collector"
  arn       = aws_lambda_function.lambda__sftp_transaction_collector[0].arn
  input     = "{}"
}

# Source: modules/lambda/main.tf

resource "aws_lambda_permission" "lambda__allow_eventbridge_invoke_sftp_transaction_collector" {
  count = var.lambda__enable_sftp_transaction_collector ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeTransactionIngestion"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda__sftp_transaction_collector[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda__sftp_transaction_collector_schedule[0].arn
}

# Source: modules/lambda/main.tf

resource "aws_cloudwatch_log_group" "lambda__audit_consumer" {
  count = var.lambda__enable_audit_consumer ? 1 : 0

  name              = "/aws/lambda/${var.lambda__name_prefix}-audit-consumer"
  retention_in_days = var.lambda__cloudwatch_log_retention_days
}

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

resource "aws_lambda_event_source_mapping" "lambda__audit_sqs" {
  count = var.lambda__enable_audit_consumer ? 1 : 0

  event_source_arn        = var.lambda__audit_sqs_arn
  function_name           = aws_lambda_function.lambda__audit_consumer[0].arn
  batch_size              = 10
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}

# Source: modules/lambda/main.tf

resource "aws_cloudwatch_log_group" "lambda__aml_consumer" {
  count = var.lambda__enable_aml_consumer ? 1 : 0

  name              = "/aws/lambda/${var.lambda__name_prefix}-aml-consumer"
  retention_in_days = var.lambda__cloudwatch_log_retention_days
}

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

resource "aws_lambda_event_source_mapping" "lambda__aml_sqs" {
  count = var.lambda__enable_aml_consumer ? 1 : 0

  event_source_arn        = var.lambda__aml_sqs_arn
  function_name           = aws_lambda_function.lambda__aml_consumer[0].arn
  batch_size              = 10
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}

# Source: modules/lambda/main.tf

resource "aws_cloudwatch_log_group" "lambda__verification" {
  count = var.lambda__enable_verification_lambda ? 1 : 0

  name              = "/aws/lambda/${var.lambda__name_prefix}-verification"
  retention_in_days = var.lambda__cloudwatch_log_retention_days
}

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

resource "aws_lambda_permission" "lambda__allow_sns_invoke_verification" {
  count = var.lambda__enable_verification_lambda ? 1 : 0

  statement_id  = "AllowExecutionFromSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda__verification[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.lambda__verification_sns_topic_arn
}

# Source: modules/lambda/main.tf

resource "aws_sns_topic_subscription" "lambda__verification_feedback" {
  count = var.lambda__enable_verification_lambda ? 1 : 0

  topic_arn = var.lambda__verification_sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda__verification[0].arn

  depends_on = [aws_lambda_permission.lambda__allow_sns_invoke_verification]
}

# Source: modules/lambda/main.tf
resource "aws_lambda_alias" "lambda__log_live" {
  count = var.lambda__enable_log_lambda ? 1 : 0

  name             = "live"
  function_name    = aws_lambda_function.lambda__log[0].function_name
  function_version = aws_lambda_function.lambda__log[0].version
}

# Source: modules/lambda/main.tf

resource "aws_lambda_alias" "lambda__aml_live" {
  count = var.lambda__enable_aml_lambda ? 1 : 0

  name             = "live"
  function_name    = aws_lambda_function.lambda__aml[0].function_name
  function_version = aws_lambda_function.lambda__aml[0].version
}

# Source: modules/lambda/main.tf

resource "aws_lambda_alias" "lambda__sftp_transaction_collector_live" {
  count = var.lambda__enable_sftp_transaction_collector ? 1 : 0

  name             = "live"
  function_name    = aws_lambda_function.lambda__sftp_transaction_collector[0].function_name
  function_version = aws_lambda_function.lambda__sftp_transaction_collector[0].version
}

# Source: modules/lambda/main.tf

resource "aws_lambda_alias" "lambda__verification_live" {
  count = var.lambda__enable_verification_lambda ? 1 : 0

  name             = "live"
  function_name    = aws_lambda_function.lambda__verification[0].function_name
  function_version = aws_lambda_function.lambda__verification[0].version
}

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
data "aws_availability_zones" "network__available" {
  state = "available"
}

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
resource "aws_route_table" "network__public" {
  vpc_id = aws_vpc.network__this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.network__this.id
  }

  tags = {
    Name = "${var.network__name_prefix}-public-rt"
  }
}

# Source: modules/network/route_tables.tf
resource "aws_route_table" "network__private" {
  count = (!var.network__enable_multi_az_nat && var.network__enable_nat_gateway) ? 1 : 0

  vpc_id = aws_vpc.network__this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.network__this[0].id
  }

  tags = {
    Name = "${var.network__name_prefix}-private-rt"
  }
}

# Source: modules/network/route_tables.tf
resource "aws_route_table" "network__private_per_az" {
  count = (var.network__enable_multi_az_nat && var.network__enable_nat_gateway) ? var.network__az_count : 0

  vpc_id = aws_vpc.network__this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.network__this[count.index].id
  }

  tags = {
    Name = "${var.network__name_prefix}-private-rt-${count.index}"
  }
}

# Source: modules/network/route_tables.tf
resource "aws_route_table" "network__db" {
  count = length(var.network__db_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.network__this.id

  tags = {
    Name = "${var.network__name_prefix}-db-rt"
  }
}

# Source: modules/network/route_tables.tf
resource "aws_route_table_association" "network__public" {
  for_each = aws_subnet.network__public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network__public.id
}

# Source: modules/network/route_tables.tf
resource "aws_route_table_association" "network__private" {
  for_each = (!var.network__enable_multi_az_nat && var.network__enable_nat_gateway) ? aws_subnet.network__private : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network__private[0].id
}

# Source: modules/network/route_tables.tf
resource "aws_route_table_association" "network__private_per_az" {
  for_each = (var.network__enable_multi_az_nat && var.network__enable_nat_gateway) ? aws_subnet.network__private : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network__private_per_az[tonumber(each.key)].id
}

# Source: modules/network/route_tables.tf
resource "aws_route_table_association" "network__db" {
  for_each = aws_subnet.network__db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.network__db[0].id
}

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
resource "aws_eip" "network__nat" {
  count = var.network__enable_nat_gateway ? (var.network__enable_multi_az_nat ? var.network__az_count : 1) : 0

  domain = "vpc"

  tags = {
    Name = var.network__enable_multi_az_nat ? "${var.network__name_prefix}-nat-eip-${count.index}" : "${var.network__name_prefix}-nat-eip"
  }
}

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
resource "aws_cloudwatch_log_group" "network__vpc_flow_logs" {
  count = var.network__enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.network__name_prefix}-flow-logs"
  retention_in_days = var.network__flow_log_retention_days

  tags = {
    Name = "${var.network__name_prefix}-vpc-flow-logs"
  }
}

# Source: modules/network/vpc_flow_logs.tf
resource "aws_iam_role" "network__vpc_flow_logs" {
  count = var.network__enable_vpc_flow_logs ? 1 : 0

  name = "${var.network__name_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Source: modules/network/vpc_flow_logs.tf
resource "aws_iam_role_policy" "network__vpc_flow_logs" {
  count = var.network__enable_vpc_flow_logs ? 1 : 0

  name = "${var.network__name_prefix}-vpc-flow-logs"
  role = aws_iam_role.network__vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "*"
    }]
  })
}

# Source: modules/network/vpc_flow_logs.tf
resource "aws_flow_log" "network__this" {
  count = var.network__enable_vpc_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.network__this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.network__vpc_flow_logs[0].arn
  iam_role_arn         = aws_iam_role.network__vpc_flow_logs[0].arn

  tags = {
    Name = "${var.network__name_prefix}-vpc-flow-log"
  }
}

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

data "aws_caller_identity" "observability__current" {}

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

resource "aws_s3_bucket_policy" "observability__cloudtrail" {
  count = var.observability__enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.observability__cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.observability__cloudtrail[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.observability__cloudtrail[0].arn}/AWSLogs/${data.aws_caller_identity.observability__current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
    ]
  })
}

# Source: modules/observability/main.tf

resource "aws_s3_bucket_server_side_encryption_configuration" "observability__cloudtrail" {
  count = var.observability__enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.observability__cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Source: modules/observability/main.tf

resource "aws_s3_bucket_public_access_block" "observability__cloudtrail" {
  count = var.observability__enable_cloudtrail ? 1 : 0

  bucket                  = aws_s3_bucket.observability__cloudtrail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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

resource "aws_cloudwatch_metric_alarm" "observability__ecs_cpu_high" {
  for_each = var.observability__enable_ecs_alarms ? var.observability__ecs_service_names : toset([])

  alarm_name          = "${var.observability__name_prefix}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.observability__ecs_cpu_alarm_threshold
  alarm_description   = "ECS ${each.key} CPU utilization above ${var.observability__ecs_cpu_alarm_threshold}%"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    ClusterName = var.observability__ecs_cluster_name
    ServiceName = "${var.observability__name_prefix}-${each.key}"
  }

  tags = {
    Name = "${var.observability__name_prefix}-${each.key}-cpu-high"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__rds_cpu_high" {
  count = var.observability__enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.observability__name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.observability__rds_cpu_alarm_threshold
  alarm_description   = "RDS CPU utilization above ${var.observability__rds_cpu_alarm_threshold}%"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    DBInstanceIdentifier = var.observability__rds_instance_identifier
  }

  tags = {
    Name = "${var.observability__name_prefix}-rds-cpu-high"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__rds_free_storage" {
  count = var.observability__enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.observability__name_prefix}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.observability__rds_free_storage_threshold_bytes
  alarm_description   = "RDS free storage below threshold"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    DBInstanceIdentifier = var.observability__rds_instance_identifier
  }

  tags = {
    Name = "${var.observability__name_prefix}-rds-low-storage"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__alb_5xx" {
  count = var.observability__enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.observability__name_prefix}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.observability__alb_5xx_alarm_threshold
  alarm_description   = "ALB 5XX errors above threshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    LoadBalancer = var.observability__alb_arn_suffix
  }

  tags = {
    Name = "${var.observability__name_prefix}-alb-5xx-high"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__ses_bounce_rate_high" {
  count = var.observability__enable_ses_alarms && var.observability__ses_identity != "" ? 1 : 0

  alarm_name          = "${var.observability__name_prefix}-ses-bounce-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.BounceRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = var.observability__ses_bounce_rate_alarm_threshold
  alarm_description   = "SES bounce rate above threshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    Identity = var.observability__ses_identity
  }

  tags = {
    Name = "${var.observability__name_prefix}-ses-bounce-rate-high"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__ses_complaint_rate_high" {
  count = var.observability__enable_ses_alarms && var.observability__ses_identity != "" ? 1 : 0

  alarm_name          = "${var.observability__name_prefix}-ses-complaint-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.ComplaintRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = var.observability__ses_complaint_rate_alarm_threshold
  alarm_description   = "SES complaint rate above threshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    Identity = var.observability__ses_identity
  }

  tags = {
    Name = "${var.observability__name_prefix}-ses-complaint-rate-high"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__ecs_memory_high" {
  for_each = var.observability__enable_ecs_alarms ? var.observability__ecs_service_names : toset([])

  alarm_name          = "${var.observability__name_prefix}-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.observability__ecs_memory_alarm_threshold
  alarm_description   = "ECS ${each.key} memory utilization above ${var.observability__ecs_memory_alarm_threshold}%"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    ClusterName = var.observability__ecs_cluster_name
    ServiceName = "${var.observability__name_prefix}-${each.key}"
  }

  tags = {
    Name = "${var.observability__name_prefix}-${each.key}-memory-high"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__ecs_running_tasks_low" {
  for_each = var.observability__enable_ecs_alarms ? var.observability__ecs_service_names : toset([])

  alarm_name          = "${var.observability__name_prefix}-${each.key}-running-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ECS ${each.key} has fewer than 1 running task"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    ClusterName = var.observability__ecs_cluster_name
    ServiceName = "${var.observability__name_prefix}-${each.key}"
  }

  tags = {
    Name = "${var.observability__name_prefix}-${each.key}-running-tasks-low"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__alb_unhealthy_hosts" {
  for_each = var.observability__enable_alb_alarms ? var.observability__target_group_arn_suffixes : {}

  alarm_name          = "${var.observability__name_prefix}-${each.key}-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.observability__alb_unhealthy_host_threshold
  alarm_description   = "ALB target group ${each.key} has ${var.observability__alb_unhealthy_host_threshold} or more unhealthy hosts"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    LoadBalancer = var.observability__alb_arn_suffix
    TargetGroup  = each.value
  }

  tags = {
    Name = "${var.observability__name_prefix}-${each.key}-unhealthy-hosts"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__alb_target_5xx" {
  for_each = var.observability__enable_alb_alarms ? var.observability__target_group_arn_suffixes : {}

  alarm_name          = "${var.observability__name_prefix}-${each.key}-target-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.observability__alb_target_5xx_threshold
  alarm_description   = "ALB target group ${each.key} target-originated 5XX errors above ${var.observability__alb_target_5xx_threshold}"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    LoadBalancer = var.observability__alb_arn_suffix
    TargetGroup  = each.value
  }

  tags = {
    Name = "${var.observability__name_prefix}-${each.key}-target-5xx-high"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_metric_alarm" "observability__alb_response_time" {
  for_each = var.observability__enable_alb_alarms ? var.observability__target_group_arn_suffixes : {}

  alarm_name          = "${var.observability__name_prefix}-${each.key}-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.observability__alb_response_time_threshold
  alarm_description   = "ALB target group ${each.key} average response time above ${var.observability__alb_response_time_threshold}s"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    LoadBalancer = var.observability__alb_arn_suffix
    TargetGroup  = each.value
  }

  tags = {
    Name = "${var.observability__name_prefix}-${each.key}-response-time-high"
  }
}

# Source: modules/observability/main.tf

resource "aws_cloudwatch_dashboard" "observability__main" {
  count = var.observability__enable_dashboard ? 1 : 0

  dashboard_name = "${var.observability__name_prefix}-ecs-alb"

  dashboard_body = jsonencode({
    widgets = concat(
      # Row 1: ECS service metrics
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 8
          height = 6
          properties = {
            title   = "ECS CPU Utilization (%)"
            metrics = [for svc in var.observability__ecs_service_names : ["AWS/ECS", "CPUUtilization", "ClusterName", var.observability__ecs_cluster_name, "ServiceName", "${var.observability__name_prefix}-${svc}"]]
            period  = 300
            stat    = "Average"
            region  = var.observability__aws_region
            yAxis   = { left = { min = 0, max = 100 } }
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 0
          width  = 8
          height = 6
          properties = {
            title   = "ECS Memory Utilization (%)"
            metrics = [for svc in var.observability__ecs_service_names : ["AWS/ECS", "MemoryUtilization", "ClusterName", var.observability__ecs_cluster_name, "ServiceName", "${var.observability__name_prefix}-${svc}"]]
            period  = 300
            stat    = "Average"
            region  = var.observability__aws_region
            yAxis   = { left = { min = 0, max = 100 } }
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 0
          width  = 8
          height = 6
          properties = {
            title   = "ECS Running Task Count"
            metrics = [for svc in var.observability__ecs_service_names : ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.observability__ecs_cluster_name, "ServiceName", "${var.observability__name_prefix}-${svc}"]]
            period  = 60
            stat    = "Average"
            region  = var.observability__aws_region
            yAxis   = { left = { min = 0 } }
          }
        },
      ],
      # Row 2: ALB traffic metrics
      [
        {
          type   = "metric"
          x      = 0
          y      = 6
          width  = 8
          height = 6
          properties = {
            title = "ALB Request Count"
            metrics = [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.observability__alb_arn_suffix, { stat = "Sum" }]
            ]
            period = 300
            region = var.observability__aws_region
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 6
          width  = 8
          height = 6
          properties = {
            title = "ALB HTTP Response Codes"
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.observability__alb_arn_suffix, { stat = "Sum", label = "Target 2XX" }],
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.observability__alb_arn_suffix, { stat = "Sum", label = "Target 4XX" }],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.observability__alb_arn_suffix, { stat = "Sum", label = "Target 5XX" }],
              ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.observability__alb_arn_suffix, { stat = "Sum", label = "ELB 5XX" }]
            ]
            period = 300
            region = var.observability__aws_region
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 6
          width  = 8
          height = 6
          properties = {
            title = "ALB Target Response Time (s)"
            metrics = [
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.observability__alb_arn_suffix, { stat = "Average", label = "Avg" }],
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.observability__alb_arn_suffix, { stat = "p99", label = "p99" }]
            ]
            period = 300
            region = var.observability__aws_region
          }
        },
      ],
      # Row 3: Per-target-group host health
      [
        {
          type   = "metric"
          x      = 0
          y      = 12
          width  = 12
          height = 6
          properties = {
            title   = "ALB Healthy Host Count"
            metrics = [for svc, suffix in var.observability__target_group_arn_suffixes : ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", suffix, "LoadBalancer", var.observability__alb_arn_suffix, { label = svc }]]
            period  = 60
            stat    = "Average"
            region  = var.observability__aws_region
            yAxis   = { left = { min = 0 } }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 12
          width  = 12
          height = 6
          properties = {
            title   = "ALB Unhealthy Host Count"
            metrics = [for svc, suffix in var.observability__target_group_arn_suffixes : ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", suffix, "LoadBalancer", var.observability__alb_arn_suffix, { label = svc }]]
            period  = 60
            stat    = "Average"
            region  = var.observability__aws_region
            yAxis   = { left = { min = 0 } }
          }
        },
      ]
    )
  })
}

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

resource "aws_kms_key" "rds__rds" {
  description             = "Customer-managed KMS key for ${var.rds__name_prefix} RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.rds__name_prefix}-rds-key"
    Environment = var.rds__environment
    Service     = "rds"
    ManagedBy   = "terraform"
  }
}

# Source: modules/rds/kms.tf

resource "aws_kms_alias" "rds__rds" {
  name          = "alias/${var.rds__name_prefix}-rds"
  target_key_id = aws_kms_key.rds__rds.key_id
}

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

resource "aws_db_parameter_group" "rds__postgres" {
  name   = "${var.rds__name_prefix}-postgres-params"
  family = var.rds__db_parameter_group_family

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  tags = {
    Name = "${var.rds__name_prefix}-postgres-params"
  }
}

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

resource "aws_ssm_parameter" "rds__db_host" {
  name  = "/${var.rds__project_name}/${var.rds__environment}/db/host"
  type  = "String"
  value = aws_db_instance.rds__postgres.address
}

# Source: modules/rds/main.tf

resource "aws_ssm_parameter" "rds__db_port" {
  name  = "/${var.rds__project_name}/${var.rds__environment}/db/port"
  type  = "String"
  value = tostring(var.rds__db_port)
}

# Source: modules/rds/main.tf

resource "aws_ssm_parameter" "rds__db_name" {
  name  = "/${var.rds__project_name}/${var.rds__environment}/db/name"
  type  = "String"
  value = var.rds__db_name
}

# Source: modules/rds/main.tf

resource "aws_ssm_parameter" "rds__client_db_url" {
  name  = "/${var.rds__project_name}/${var.rds__environment}/db/client/url"
  type  = "String"
  value = local.db_jdbc_url
}

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

resource "aws_s3_bucket_versioning" "s3__frontend" {
  bucket = aws_s3_bucket.s3__frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_server_side_encryption_configuration" "s3__frontend" {
  bucket = aws_s3_bucket.s3__frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_public_access_block" "s3__frontend" {
  bucket = aws_s3_bucket.s3__frontend.id

  block_public_acls       = !var.s3__frontend_bucket_allow_public
  block_public_policy     = !var.s3__frontend_bucket_allow_public
  ignore_public_acls      = !var.s3__frontend_bucket_allow_public
  restrict_public_buckets = !var.s3__frontend_bucket_allow_public
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_ownership_controls" "s3__frontend" {
  bucket = aws_s3_bucket.s3__frontend.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_website_configuration" "s3__frontend" {
  count  = var.s3__frontend_bucket_allow_public ? 1 : 0
  bucket = aws_s3_bucket.s3__frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_policy" "s3__frontend_public_read" {
  count  = var.s3__frontend_bucket_allow_public ? 1 : 0
  bucket = aws_s3_bucket.s3__frontend.id

  depends_on = [aws_s3_bucket_public_access_block.s3__frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.s3__frontend.arn}/*"
    }]
  })
}

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

resource "aws_s3_bucket_versioning" "s3__verification" {
  count = var.s3__enable_verification_bucket ? 1 : 0

  bucket = aws_s3_bucket.s3__verification[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_server_side_encryption_configuration" "s3__verification" {
  count = var.s3__enable_verification_bucket ? 1 : 0

  bucket = aws_s3_bucket.s3__verification[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_public_access_block" "s3__verification" {
  count = var.s3__enable_verification_bucket ? 1 : 0

  bucket = aws_s3_bucket.s3__verification[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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

resource "aws_s3_bucket_versioning" "s3__transaction_sftp" {
  count = var.s3__enable_transaction_sftp_bucket ? 1 : 0

  bucket = aws_s3_bucket.s3__transaction_sftp[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_server_side_encryption_configuration" "s3__transaction_sftp" {
  count = var.s3__enable_transaction_sftp_bucket ? 1 : 0

  bucket = aws_s3_bucket.s3__transaction_sftp[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Source: modules/s3/main.tf

resource "aws_s3_bucket_public_access_block" "s3__transaction_sftp" {
  count = var.s3__enable_transaction_sftp_bucket ? 1 : 0

  bucket = aws_s3_bucket.s3__transaction_sftp[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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

data "aws_caller_identity" "security__current" {}

# Source: modules/security/main.tf

locals {
  # When a lab role override is supplied, skip all IAM role creation and use the
  # pre-existing role (for example, LabRole in Learner Lab which blocks iam:CreateRole).
  effective_lab_role_arn = var.security__lab_role_arn != "" ? var.security__lab_role_arn : (var.security__lab_role_name != "" ? "arn:aws:iam::${data.aws_caller_identity.security__current.account_id}:role/${var.security__lab_role_name}" : "")
  use_lab_role           = local.effective_lab_role_arn != ""
}

# Source: modules/security/main.tf

resource "aws_security_group" "security__alb" {
  name        = "${var.security__name_prefix}-alb-sg"
  description = "Allow inbound HTTP and HTTPS traffic to ALB."
  vpc_id      = var.security__vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.security__name_prefix}-alb-sg"
  }
}

# Source: modules/security/main.tf

resource "aws_security_group" "security__ecs_service" {
  name        = "${var.security__name_prefix}-ecs-sg"
  description = "Allow app traffic from ALB and internal ECS traffic."
  vpc_id      = var.security__vpc_id

  ingress {
    description     = "Backend traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.security__alb.id]
  }

  ingress {
    description = "Service-to-service traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.security__name_prefix}-ecs-sg"
  }
}

# Source: modules/security/main.tf

resource "aws_security_group" "security__lambda" {
  name        = "${var.security__name_prefix}-lambda-sg"
  description = "Security group for Lambda functions in VPC."
  vpc_id      = var.security__vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.security__name_prefix}-lambda-sg"
  }
}

# Source: modules/security/main.tf

resource "aws_security_group" "security__db" {
  name        = "${var.security__name_prefix}-db-sg"
  description = "Allow PostgreSQL from ECS services and Lambda."
  vpc_id      = var.security__vpc_id

  ingress {
    description     = "PostgreSQL from ECS services"
    from_port       = var.security__db_port
    to_port         = var.security__db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.security__ecs_service.id]
  }

  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = var.security__db_port
    to_port         = var.security__db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.security__lambda.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.security__name_prefix}-db-sg"
  }
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__ecs_task_execution_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role" "security__ecs_task_execution" {
  count              = local.use_lab_role ? 0 : 1
  name               = "${var.security__name_prefix}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.security__ecs_task_execution_assume.json
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__ecs_task_execution_managed" {
  count      = local.use_lab_role ? 0 : 1
  role       = aws_iam_role.security__ecs_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__ecs_task_execution_extra" {
  statement {
    sid     = "ReadSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.security__jwt_hmac.arn,
      aws_secretsmanager_secret.security__root_admin_password.arn,
      aws_secretsmanager_secret.security__db_username.arn,
      aws_secretsmanager_secret.security__db_password.arn,
    ]
  }

  statement {
    sid    = "ReadSsmParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.security__aws_region}:${data.aws_caller_identity.security__current.account_id}:parameter/${var.security__project_name}/${var.security__environment}/*",
    ]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__ecs_task_execution_extra" {
  count  = local.use_lab_role ? 0 : 1
  name   = "${var.security__name_prefix}-ecs-task-exec-extra"
  role   = aws_iam_role.security__ecs_task_execution[0].id
  policy = data.aws_iam_policy_document.security__ecs_task_execution_extra.json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__ecs_task_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role" "security__ecs_task" {
  for_each = local.use_lab_role ? toset([]) : toset(["user", "client", "transaction"])

  name               = "${var.security__name_prefix}-ecs-task-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.security__ecs_task_assume.json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role" "security__log_lambda" {
  count              = local.use_lab_role ? 0 : 1
  name               = "${var.security__name_prefix}-log-lambda"
  assume_role_policy = data.aws_iam_policy_document.security__lambda_assume.json
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__log_lambda_basic" {
  count      = local.use_lab_role ? 0 : 1
  role       = aws_iam_role.security__log_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__log_lambda_vpc" {
  count      = local.use_lab_role ? 0 : 1
  role       = aws_iam_role.security__log_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__log_lambda_secrets" {
  statement {
    sid     = "ReadLogSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.security__jwt_hmac.arn,
      aws_secretsmanager_secret.security__db_username.arn,
      aws_secretsmanager_secret.security__db_password.arn,
    ]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__log_lambda_secrets" {
  count  = local.use_lab_role ? 0 : 1
  name   = "${var.security__name_prefix}-log-lambda-secrets"
  role   = aws_iam_role.security__log_lambda[0].id
  policy = data.aws_iam_policy_document.security__log_lambda_secrets.json
}

# Source: modules/security/main.tf

resource "aws_iam_role" "security__aml_lambda" {
  count              = local.use_lab_role ? 0 : 1
  name               = "${var.security__name_prefix}-aml-lambda"
  assume_role_policy = data.aws_iam_policy_document.security__lambda_assume.json
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__aml_lambda_basic" {
  count      = local.use_lab_role ? 0 : 1
  role       = aws_iam_role.security__aml_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__aml_lambda_secrets" {
  statement {
    sid    = "ReadAmlSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = compact([
      var.security__aml_sftp_key_secret_arn,
      aws_secretsmanager_secret.security__jwt_hmac.arn,
    ])
  }

  statement {
    sid    = "ReadLogApiUrlParameter"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.security__aws_region}:${data.aws_caller_identity.security__current.account_id}:parameter/${var.security__project_name}/${var.security__environment}/service/log/url",
    ]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__aml_lambda_secrets" {
  count  = local.use_lab_role ? 0 : 1
  name   = "${var.security__name_prefix}-aml-lambda-secrets"
  role   = aws_iam_role.security__aml_lambda[0].id
  policy = data.aws_iam_policy_document.security__aml_lambda_secrets.json
}

# Source: modules/security/main.tf

resource "aws_iam_role" "security__sftp_transaction_collector" {
  count = var.security__enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  name               = "${var.security__name_prefix}-sftp-transaction-collector"
  assume_role_policy = data.aws_iam_policy_document.security__lambda_assume.json
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__sftp_transaction_collector_basic" {
  count = var.security__enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.security__sftp_transaction_collector[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__sftp_transaction_collector_s3" {
  count = var.security__enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ReadTransactionSftpBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = compact([
      var.security__transaction_sftp_bucket_arn,
      "${var.security__transaction_sftp_bucket_arn}/*",
    ])
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__sftp_transaction_collector_s3" {
  count = var.security__enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-sftp-transaction-collector-s3"
  role   = aws_iam_role.security__sftp_transaction_collector[0].id
  policy = data.aws_iam_policy_document.security__sftp_transaction_collector_s3[0].json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__sftp_transaction_collector_secrets" {
  count = var.security__enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ReadTransactionIngestionJwtSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.security__jwt_hmac.arn,
    ]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__sftp_transaction_collector_secrets" {
  count = var.security__enable_sftp_transaction_collector && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-sftp-transaction-collector-secrets"
  role   = aws_iam_role.security__sftp_transaction_collector[0].id
  policy = data.aws_iam_policy_document.security__sftp_transaction_collector_secrets[0].json
}

# Source: modules/security/main.tf

resource "aws_iam_role" "security__audit_consumer_lambda" {
  count = var.security__enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  name               = "${var.security__name_prefix}-audit-consumer-lambda"
  assume_role_policy = data.aws_iam_policy_document.security__lambda_assume.json
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__audit_consumer_lambda_basic" {
  count = var.security__enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.security__audit_consumer_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__audit_consumer_lambda_vpc" {
  count = var.security__enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.security__audit_consumer_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__audit_consumer_lambda" {
  count = var.security__enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ConsumeAuditQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = compact([var.security__audit_sqs_arn, var.security__audit_dlq_arn])
  }

  statement {
    sid    = "WriteDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [var.security__audit_dynamodb_table_arn]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__audit_consumer_lambda" {
  count = var.security__enable_audit_pipeline && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-audit-consumer-lambda"
  role   = aws_iam_role.security__audit_consumer_lambda[0].id
  policy = data.aws_iam_policy_document.security__audit_consumer_lambda[0].json
}

# Source: modules/security/main.tf

resource "aws_iam_role" "security__aml_consumer_lambda" {
  count = var.security__enable_aml_pipeline && !local.use_lab_role ? 1 : 0

  name               = "${var.security__name_prefix}-aml-consumer-lambda"
  assume_role_policy = data.aws_iam_policy_document.security__lambda_assume.json
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__aml_consumer_lambda_basic" {
  count = var.security__enable_aml_pipeline && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.security__aml_consumer_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__aml_consumer_lambda" {
  count = var.security__enable_aml_pipeline && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ConsumeAmlQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = compact([var.security__aml_sqs_arn, var.security__aml_dlq_arn])
  }

  statement {
    sid    = "WriteDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [var.security__aml_dynamodb_table_arn]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__aml_consumer_lambda" {
  count = var.security__enable_aml_pipeline && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-aml-consumer-lambda"
  role   = aws_iam_role.security__aml_consumer_lambda[0].id
  policy = data.aws_iam_policy_document.security__aml_consumer_lambda[0].json
}

# Source: modules/security/main.tf

resource "aws_iam_role" "security__verification_lambda" {
  count = var.security__enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  name               = "${var.security__name_prefix}-verification-lambda"
  assume_role_policy = data.aws_iam_policy_document.security__lambda_assume.json
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy_attachment" "security__verification_lambda_basic" {
  count = var.security__enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  role       = aws_iam_role.security__verification_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__verification_lambda" {
  count = var.security__enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ReadVerificationBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.security__verification_bucket_arn,
      "${var.security__verification_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "PublishVerificationSns"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [var.security__verification_sns_topic_arn]
  }

  statement {
    sid    = "ReadVerificationJwtSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [aws_secretsmanager_secret.security__jwt_hmac.arn]
  }

  statement {
    sid    = "SendVerificationEmailViaSes"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__verification_lambda" {
  count = var.security__enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-verification-lambda"
  role   = aws_iam_role.security__verification_lambda[0].id
  policy = data.aws_iam_policy_document.security__verification_lambda[0].json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__ecs_client_ses_send" {
  count = var.security__enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "SendVerificationEmailViaSes"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__ecs_task_client_ses_send" {
  count = var.security__enable_verification_pipeline && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-ecs-task-client-ses-send"
  role   = aws_iam_role.security__ecs_task["client"].id
  policy = data.aws_iam_policy_document.security__ecs_client_ses_send[0].json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__ecs_client_publish_verification_sns" {
  count = var.security__enable_verification_pipeline && var.security__verification_sns_topic_arn != "" && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "PublishVerificationRequestedEvents"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [var.security__verification_sns_topic_arn]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__ecs_task_client_publish_verification_sns" {
  count = var.security__enable_verification_pipeline && var.security__verification_sns_topic_arn != "" && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-ecs-task-client-verification-sns-publish"
  role   = aws_iam_role.security__ecs_task["client"].id
  policy = data.aws_iam_policy_document.security__ecs_client_publish_verification_sns[0].json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__ecs_client_write_verification_s3" {
  count = var.security__enable_verification_pipeline && var.security__verification_bucket_arn != "" && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "WriteVerificationDocuments"
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = ["${var.security__verification_bucket_arn}/*"]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__ecs_task_client_write_verification_s3" {
  count = var.security__enable_verification_pipeline && var.security__verification_bucket_arn != "" && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-ecs-task-client-verification-s3-write"
  role   = aws_iam_role.security__ecs_task["client"].id
  policy = data.aws_iam_policy_document.security__ecs_client_write_verification_s3[0].json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__ecs_sqs_send" {
  count = (var.security__enable_audit_pipeline || var.security__enable_aml_pipeline) && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "SendToSqs"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
    ]
    resources = compact([var.security__audit_sqs_arn, var.security__aml_sqs_arn])
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__ecs_task_sqs" {
  for_each = (var.security__enable_audit_pipeline || var.security__enable_aml_pipeline) && !local.use_lab_role ? toset(["user", "client", "transaction"]) : toset([])

  name   = "${var.security__name_prefix}-ecs-task-${each.key}-sqs"
  role   = aws_iam_role.security__ecs_task[each.key].id
  policy = data.aws_iam_policy_document.security__ecs_sqs_send[0].json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__ecs_transaction_s3_read" {
  count = var.security__enable_sftp_transaction_collector && var.security__transaction_sftp_bucket_arn != "" && !local.use_lab_role ? 1 : 0

  statement {
    sid    = "ReadTransactionIngestionS3Source"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.security__transaction_sftp_bucket_arn,
      "${var.security__transaction_sftp_bucket_arn}/*",
    ]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_role_policy" "security__ecs_task_transaction_s3_read" {
  count = var.security__enable_sftp_transaction_collector && var.security__transaction_sftp_bucket_arn != "" && !local.use_lab_role ? 1 : 0

  name   = "${var.security__name_prefix}-ecs-task-transaction-s3-read"
  role   = aws_iam_role.security__ecs_task["transaction"].id
  policy = data.aws_iam_policy_document.security__ecs_transaction_s3_read[0].json
}

# Source: modules/security/main.tf

data "aws_iam_policy_document" "security__terraform_backend_access" {
  count = var.security__create_backend_iam_policy ? 1 : 0

  statement {
    sid    = "StateBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.security__backend_state_bucket_name}",
    ]
  }

  statement {
    sid    = "StateBucketObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.security__backend_state_bucket_name}/*",
    ]
  }

  statement {
    sid    = "StateLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.security__aws_region}:${data.aws_caller_identity.security__current.account_id}:table/${var.security__backend_lock_table_name}",
    ]
  }
}

# Source: modules/security/main.tf

resource "aws_iam_policy" "security__terraform_backend_access" {
  count = var.security__create_backend_iam_policy ? 1 : 0

  name        = "${var.security__name_prefix}-terraform-backend-access"
  description = "IAM policy for Terraform S3 backend and DynamoDB lock table access."
  policy      = data.aws_iam_policy_document.security__terraform_backend_access[0].json
}

# Source: modules/security/secrets.tf
locals {
  jwt_hmac_secret_value     = var.security__jwt_hmac_secret != "" ? var.security__jwt_hmac_secret : "brainboard-placeholder"
  root_admin_password_value = var.security__root_admin_password != "" ? var.security__root_admin_password : "brainboard-placeholder"
  db_password_value         = "brainboard-placeholder"
}

# Source: modules/security/secrets.tf

resource "aws_secretsmanager_secret" "security__jwt_hmac" {
  name                    = "/${var.security__project_name}/${var.security__environment}/jwt/hmac_secret"
  description             = "Shared JWT HMAC secret for user/client/transaction/log."
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.security__project_name}-${var.security__environment}-jwt-hmac"
    Environment = var.security__environment
    ManagedBy   = "terraform"
  }
}

# Source: modules/security/secrets.tf

resource "aws_secretsmanager_secret_version" "security__jwt_hmac" {
  secret_id     = aws_secretsmanager_secret.security__jwt_hmac.id
  secret_string = local.jwt_hmac_secret_value
}

# Source: modules/security/secrets.tf

resource "aws_secretsmanager_secret" "security__root_admin_password" {
  name                    = "/${var.security__project_name}/${var.security__environment}/user/root_admin_password"
  description             = "Initial root admin password for user service."
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.security__project_name}-${var.security__environment}-root-admin-password"
    Environment = var.security__environment
    ManagedBy   = "terraform"
  }
}

# Source: modules/security/secrets.tf

resource "aws_secretsmanager_secret_version" "security__root_admin_password" {
  secret_id     = aws_secretsmanager_secret.security__root_admin_password.id
  secret_string = local.root_admin_password_value
}

# Source: modules/security/secrets.tf

resource "aws_secretsmanager_secret" "security__db_username" {
  name                    = "/${var.security__project_name}/${var.security__environment}/db/username"
  description             = "PostgreSQL username shared by services."
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.security__project_name}-${var.security__environment}-db-username"
    Environment = var.security__environment
    ManagedBy   = "terraform"
  }
}

# Source: modules/security/secrets.tf

resource "aws_secretsmanager_secret_version" "security__db_username" {
  secret_id     = aws_secretsmanager_secret.security__db_username.id
  secret_string = var.security__db_username
}

# Source: modules/security/secrets.tf

resource "aws_secretsmanager_secret" "security__db_password" {
  name                    = "/${var.security__project_name}/${var.security__environment}/db/password"
  description             = "PostgreSQL password shared by services."
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.security__project_name}-${var.security__environment}-db-password"
    Environment = var.security__environment
    ManagedBy   = "terraform"
  }
}

# Source: modules/security/secrets.tf

resource "aws_secretsmanager_secret_version" "security__db_password" {
  secret_id     = aws_secretsmanager_secret.security__db_password.id
  secret_string = local.db_password_value
}

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
resource "aws_ses_domain_identity" "ses__this" {
  count = var.ses__domain != "" ? 1 : 0

  domain = var.ses__domain
}

# Source: modules/ses/main.tf
resource "aws_ses_domain_dkim" "ses__this" {
  count = var.ses__domain != "" ? 1 : 0

  domain = aws_ses_domain_identity.ses__this[0].domain
}

# Source: modules/ses/main.tf
resource "aws_ses_domain_mail_from" "ses__this" {
  count = var.ses__domain != "" ? 1 : 0

  domain           = aws_ses_domain_identity.ses__this[0].domain
  mail_from_domain = "${var.ses__mail_from_subdomain}.${var.ses__domain}"
}

# Source: modules/ses/main.tf

resource "aws_ses_identity_notification_topic" "ses__events" {
  for_each = (
    var.ses__enable_ses &&
    var.ses__notification_topic_arn != "" &&
    local.notification_identity != ""
  ) ? toset(["Bounce", "Complaint", "Delivery"]) : toset([])

  identity          = local.notification_identity
  notification_type = each.value
  topic_arn         = var.ses__notification_topic_arn
}

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
resource "aws_sns_topic_subscription" "sns__verification_email" {
  count = var.sns__enable_verification_pipeline && var.sns__notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.sns__verification[0].arn
  protocol  = "email"
  endpoint  = var.sns__notification_email
}

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
resource "aws_sns_topic_subscription" "sns__alarm_email" {
  count = var.sns__enable_alarm_topic && var.sns__alarm_notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.sns__alarm_notifications[0].arn
  protocol  = "email"
  endpoint  = var.sns__alarm_notification_email
}

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
