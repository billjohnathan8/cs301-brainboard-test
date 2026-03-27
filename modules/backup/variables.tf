#--------------------------------------------------------------
# Backup Module - Variables
#--------------------------------------------------------------

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "enable_backup" {
  description = "Enable AWS Backup vault and plan."
  type        = bool
  default     = false
}

variable "backup_schedule" {
  description = "Backup schedule in cron expression (UTC)."
  type        = string
  default     = "cron(0 3 * * ? *)" # Daily at 3 AM UTC
}

variable "backup_retention_days" {
  description = "Number of days to retain backups."
  type        = number
  default     = 30
}

variable "rds_instance_arn" {
  description = "ARN of the RDS instance to back up."
  type        = string
  default     = ""
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs to back up."
  type        = list(string)
  default     = []
}
