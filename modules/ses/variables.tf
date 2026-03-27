#--------------------------------------------------------------
# SES Module - Variables
#--------------------------------------------------------------

variable "enable_ses" {
  description = "Enable SES email identity and domain configuration."
  type        = bool
  default     = false
}

variable "sender_email" {
  description = "SES verified sender email for email identity verification. Leave empty to skip."
  type        = string
  default     = ""
}

variable "domain" {
  description = "Domain for SES domain identity with DKIM/SPF. Leave empty to use email identity instead."
  type        = string
  default     = ""
}

variable "mail_from_subdomain" {
  description = "Subdomain prefix for custom MAIL FROM domain (e.g. 'mail' creates mail.example.com)."
  type        = string
  default     = "mail"
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for SES bounce/complaint/delivery notifications."
  type        = string
  default     = ""
}
