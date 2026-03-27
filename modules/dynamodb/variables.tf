#--------------------------------------------------------------
# DynamoDB Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "enable_audit_table" {
  description = "Create audit logs DynamoDB table."
  type        = bool
  default     = false
}

variable "enable_aml_table" {
  description = "Create AML reports DynamoDB table."
  type        = bool
  default     = false
}

variable "billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "The billing_mode value must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "enable_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery."
  type        = bool
  default     = true
}

variable "enable_ttl" {
  description = "Enable TTL on DynamoDB tables."
  type        = bool
  default     = false
}
