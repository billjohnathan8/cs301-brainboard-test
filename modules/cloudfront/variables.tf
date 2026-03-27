#--------------------------------------------------------------
# CloudFront Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "use_custom_domain" {
  description = "Whether custom domain is enabled."
  type        = bool
}

variable "app_domain_name" {
  description = "Custom application domain."
  type        = string
}

variable "cloudfront_price_class" {
  description = "CloudFront price class."
  type        = string
}

variable "frontend_certificate_arn" {
  description = "ACM cert ARN for CloudFront."
  type        = string
  default     = null
  nullable    = true
}

variable "alb_origin_domain_name" {
  description = "ALB origin domain name (custom domain mode)."
  type        = string
  default     = null
  nullable    = true
}

variable "alb_dns_name" {
  description = "ALB DNS name."
  type        = string
}

variable "enable_log_api_origin" {
  description = "Enable CloudFront origin and path rules for the log API Gateway."
  type        = bool
  default     = false
}

variable "log_api_origin_domain_name" {
  description = "API Gateway origin domain."
  type        = string
  default     = null
  nullable    = true
}

variable "frontend_bucket_id" {
  description = "Frontend S3 bucket ID."
  type        = string
}

variable "frontend_bucket_arn" {
  description = "Frontend S3 bucket ARN."
  type        = string
}

variable "frontend_bucket_regional_domain_name" {
  description = "Frontend S3 bucket regional domain name."
  type        = string
}

variable "waf_arn" {
  description = "Optional WAF ARN to attach to CloudFront."
  type        = string
  default     = null
  nullable    = true
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for creating DNS records (school-provided)."
  type        = string
  default     = ""
}

variable "manage_route53_record" {
  description = "Whether Terraform should manage the CloudFront Route53 alias record."
  type        = bool
  default     = false
}

variable "enable_cloudfront_oac" {
  description = "Create CloudFront Origin Access Control for the S3 frontend bucket. Disable when LabRole blocks cloudfront:CreateOriginAccessControl."
  type        = bool
  default     = true
}

check "log_api_origin_requires_domain_name" {
  assert {
    condition     = !var.enable_log_api_origin || (var.log_api_origin_domain_name != null && trimspace(var.log_api_origin_domain_name) != "")
    error_message = "log_api_origin_domain_name must be set when enable_log_api_origin is true."
  }
}
