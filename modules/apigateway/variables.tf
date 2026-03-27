#--------------------------------------------------------------
# API Gateway Module - Variables
#--------------------------------------------------------------

variable "project_name" {
  description = "Project name used in parameter path."
  type        = string
}

variable "environment" {
  description = "Environment name used in parameter path."
  type        = string
}

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
}

variable "use_custom_domain" {
  description = "Whether custom domain is enabled."
  type        = bool
}

variable "app_domain_name" {
  description = "Application domain name when custom domain is enabled."
  type        = string
}

variable "log_lambda_invoke_arn" {
  description = "Lambda invoke ARN for API integration."
  type        = string
}

variable "log_lambda_function_name" {
  description = "Lambda function name for API invoke permission."
  type        = string
}
