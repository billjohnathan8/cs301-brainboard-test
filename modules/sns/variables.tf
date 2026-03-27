#--------------------------------------------------------------
# SNS Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix for SNS resources."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "enable_verification_pipeline" {
  description = "Create verification SNS topic and subscriptions."
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Email endpoint for SNS topic subscription. Leave empty to skip email subscription."
  type        = string
  default     = ""
}

variable "enable_alarm_topic" {
  description = "Create a dedicated SNS topic for CloudWatch alarm notifications."
  type        = bool
  default     = false
}

variable "alarm_notification_email" {
  description = "Email endpoint for CloudWatch alarm SNS subscription. Leave empty to skip email subscription."
  type        = string
  default     = ""
}
