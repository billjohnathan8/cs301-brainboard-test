#--------------------------------------------------------------
# WAF Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "enable_waf" {
  description = "Attach WAF to CloudFront."
  type        = bool
}
