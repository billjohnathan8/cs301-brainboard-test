#--------------------------------------------------------------
# ALB Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix for ALB resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB target groups are deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs used by the ALB."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID attached to ALB."
  type        = string
}

variable "use_custom_domain" {
  description = "Whether HTTPS listener is required for custom domain."
  type        = bool
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listener."
  type        = string
  default     = null
  nullable    = true
}

variable "service_health_check_path" {
  description = "HTTP health endpoint path used by ALB target groups."
  type        = string
  default     = "/health"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for creating DNS records (school-provided)."
  type        = string
  default     = ""
}

variable "alb_subdomain" {
  description = "Subdomain for the ALB (e.g., 'alb' for alb.yourdomain.com)."
  type        = string
  default     = "alb"
}

variable "manage_route53_record" {
  description = "Whether Terraform should manage the ALB Route53 alias record."
  type        = bool
  default     = false
}

variable "enable_blue_green_tg" {
  description = "Create green target group pairs alongside blue ones. Required for CodeDeploy blue/green deployments; set false to avoid naming collisions when CodeDeploy is disabled."
  type        = bool
  default     = true
}
