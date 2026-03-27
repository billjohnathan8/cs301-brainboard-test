#--------------------------------------------------------------
# Observability Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "alarm_notification_topic_arn" {
  description = "SNS topic ARN used for CloudWatch alarm and recovery notifications. Leave empty to disable alarm actions."
  type        = string
  default     = ""
}

# --- CloudTrail ---

variable "enable_cloudtrail" {
  description = "Enable AWS CloudTrail."
  type        = bool
  default     = false
}

variable "cloudtrail_bucket_force_destroy" {
  description = "Allow Terraform destroy to delete non-empty CloudTrail bucket."
  type        = bool
  default     = false
}

# --- ECS Alarms ---

variable "enable_ecs_alarms" {
  description = "Create CloudWatch alarms for ECS services."
  type        = bool
  default     = false
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for alarm dimensions."
  type        = string
  default     = ""
}

variable "ecs_service_names" {
  description = "Set of ECS service names for alarm creation."
  type        = set(string)
  default     = []
}

variable "ecs_cpu_alarm_threshold" {
  description = "CPU utilization percent threshold for ECS alarms."
  type        = number
  default     = 85
}

# --- RDS Alarms ---

variable "enable_rds_alarms" {
  description = "Create CloudWatch alarms for RDS."
  type        = bool
  default     = false
}

variable "rds_instance_identifier" {
  description = "RDS instance identifier for alarm dimensions."
  type        = string
  default     = ""
}

variable "rds_cpu_alarm_threshold" {
  description = "CPU utilization percent threshold for RDS alarm."
  type        = number
  default     = 80
}

variable "rds_free_storage_threshold_bytes" {
  description = "Free storage space threshold in bytes for RDS alarm."
  type        = number
  default     = 2147483648 # 2 GiB
}

# --- ALB Alarms ---

variable "enable_alb_alarms" {
  description = "Create CloudWatch alarms for ALB."
  type        = bool
  default     = false
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for alarm dimensions."
  type        = string
  default     = ""
}

variable "alb_5xx_alarm_threshold" {
  description = "5XX error count threshold for ALB alarm."
  type        = number
  default     = 10
}

# --- SES Alarms ---

variable "enable_ses_alarms" {
  description = "Create CloudWatch alarms for SES sender reputation."
  type        = bool
  default     = false
}

variable "ses_identity" {
  description = "SES identity dimension value (sender email or domain)."
  type        = string
  default     = ""
}

variable "ses_bounce_rate_alarm_threshold" {
  description = "Bounce rate threshold for SES reputation alarm."
  type        = number
  default     = 0.05
}

variable "ses_complaint_rate_alarm_threshold" {
  description = "Complaint rate threshold for SES reputation alarm."
  type        = number
  default     = 0.001
}

# --- ECS Memory Alarms ---

variable "ecs_memory_alarm_threshold" {
  description = "Memory utilization percent threshold for ECS alarms."
  type        = number
  default     = 85
}

# --- Per-Target-Group ALB Alarms ---

variable "target_group_arn_suffixes" {
  description = "ALB target group ARN suffixes keyed by service name, for per-target-group alarms."
  type        = map(string)
  default     = {}
}

variable "alb_unhealthy_host_threshold" {
  description = "Unhealthy host count threshold for per-target-group ALB alarms."
  type        = number
  default     = 1
}

variable "alb_target_5xx_threshold" {
  description = "Target-originated 5XX error count threshold for per-target-group ALB alarms."
  type        = number
  default     = 10
}

variable "alb_response_time_threshold" {
  description = "Average target response time threshold in seconds for per-target-group ALB alarms."
  type        = number
  default     = 5
}

# --- Dashboard ---

variable "enable_dashboard" {
  description = "Create a CloudWatch dashboard for ECS and ALB metrics."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region for CloudWatch dashboard metric widgets."
  type        = string
  default     = "ap-southeast-1"
}
