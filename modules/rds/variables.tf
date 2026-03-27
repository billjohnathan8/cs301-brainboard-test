#--------------------------------------------------------------
# RDS Module - Variables
#--------------------------------------------------------------

variable "project_name" {
  description = "Project name for parameter paths."
  type        = string
}

variable "environment" {
  description = "Environment name for parameter paths."
  type        = string
}

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for DB subnet group."
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group ID for RDS."
  type        = string
}

variable "db_password_value" {
  description = "Database password value."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
}

variable "db_username" {
  description = "PostgreSQL username."
  type        = string
}

variable "db_port" {
  description = "PostgreSQL port."
  type        = number
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_engine_version" {
  description = "Optional PostgreSQL engine version."
  type        = string
  default     = ""
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Maximum autoscaling storage in GiB."
  type        = number
}

variable "db_multi_az" {
  description = "Enable Multi-AZ."
  type        = bool
}

variable "db_backup_retention_days" {
  description = "Backup retention in days."
  type        = number
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy."
  type        = bool
}

variable "db_deletion_protection" {
  description = "Enable deletion protection."
  type        = bool
}

variable "db_parameter_group_family" {
  description = "DB parameter group family (e.g. postgres17)."
  type        = string
  default     = "postgres17"
}

variable "performance_insights_enabled" {
  description = "Enable RDS Performance Insights."
  type        = bool
  default     = true
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication."
  type        = bool
  default     = false
}
