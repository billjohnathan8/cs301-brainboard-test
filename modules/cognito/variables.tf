#--------------------------------------------------------------
# Cognito Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "allow_admin_create_user_only" {
  description = "If true, only admins can create new users."
  type        = bool
  default     = true
}

variable "callback_urls" {
  description = "OAuth callback URLs for the app client."
  type        = list(string)
  default     = []
}

variable "logout_urls" {
  description = "OAuth logout URLs for the app client."
  type        = list(string)
  default     = []
}

variable "cognito_domain_prefix" {
  description = "Cognito hosted UI domain prefix. Leave empty to skip domain creation."
  type        = string
  default     = ""
}

variable "access_token_validity_hours" {
  description = "Access token validity in hours."
  type        = number
  default     = 1
}

variable "id_token_validity_hours" {
  description = "ID token validity in hours."
  type        = number
  default     = 1
}

variable "refresh_token_validity_days" {
  description = "Refresh token validity in days."
  type        = number
  default     = 30
}

variable "aws_region" {
  description = "AWS region for constructing Cognito endpoint URLs."
  type        = string
}

variable "mfa_configuration" {
  description = "MFA configuration. Can be OFF, ON, or OPTIONAL."
  type        = string
  default     = "OFF"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "The mfa_configuration value must be one of OFF, ON, or OPTIONAL."
  }
}
