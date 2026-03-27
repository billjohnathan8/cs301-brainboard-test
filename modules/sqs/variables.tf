#--------------------------------------------------------------
# SQS Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix for SQS resources."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "enable_audit_pipeline" {
  description = "Create audit SQS queue and DLQ."
  type        = bool
  default     = false
}

variable "enable_aml_pipeline" {
  description = "Create AML SQS queue and DLQ."
  type        = bool
  default     = false
}

variable "audit_visibility_timeout" {
  description = "Visibility timeout for audit SQS queue (should be >= Lambda timeout)."
  type        = number
  default     = 60
}

variable "aml_visibility_timeout" {
  description = "Visibility timeout for AML SQS queue (should be >= Lambda timeout)."
  type        = number
  default     = 180
}

variable "message_retention_seconds" {
  description = "How long messages are retained in SQS queues."
  type        = number
  default     = 1209600 # 14 days
}

variable "dlq_retention_seconds" {
  description = "How long messages are retained in DLQ."
  type        = number
  default     = 1209600 # 14 days
}

variable "max_receive_count" {
  description = "Number of receive attempts before message is sent to DLQ."
  type        = number
  default     = 3
}
