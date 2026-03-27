#--------------------------------------------------------------
# ACM Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix for resource tags."
  type        = string
}

variable "app_domain_name" {
  description = "Base domain for the certificate (e.g., itsag2t3.com)."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 zone ID where DNS validation records will be created."
  type        = string
  default     = ""
}

variable "alb_origin_subdomain" {
  description = "Subdomain for ALB origin (e.g., 'api' for api.yourdomain.com)."
  type        = string
  default     = "api"
}

variable "manage_dns_validation_records" {
  description = "Whether Terraform should create Route53 records for ACM DNS validation."
  type        = bool
  default     = false
}

variable "wait_for_validation" {
  description = "Wait for ACM certificate validation to complete."
  type        = bool
  default     = true
}

check "route53_zone_required_when_managing_validation_records" {
  assert {
    condition     = !var.manage_dns_validation_records || trimspace(var.route53_zone_id) != ""
    error_message = "route53_zone_id must be set when manage_dns_validation_records is true."
  }
}
