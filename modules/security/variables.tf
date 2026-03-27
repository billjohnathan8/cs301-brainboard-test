#--------------------------------------------------------------
# Security Module - Variables
#--------------------------------------------------------------

variable "lab_role_arn" {
  description = "Pre-existing IAM role ARN to use instead of creating new roles (e.g. LabRole in Learner Lab). When set, all aws_iam_role creation is skipped and this ARN is returned for all role outputs."
  type        = string
  default     = ""
}

variable "lab_role_name" {
  description = "Pre-existing IAM role name to use when lab_role_arn is not supplied (for example, LabRole in Learner Lab)."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name used in parameter and secret paths."
  type        = string
}

variable "environment" {
  description = "Environment name used in parameter and secret paths."
  type        = string
}

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups are created."
  type        = string
}

variable "db_port" {
  description = "PostgreSQL port."
  type        = number
}

variable "db_username" {
  description = "Database username stored in Secrets Manager."
  type        = string
}

variable "jwt_hmac_secret" {
  description = "JWT HMAC secret override."
  type        = string
  default     = ""
  sensitive   = true
}

variable "root_admin_password" {
  description = "Root admin password override."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aml_sftp_key_secret_arn" {
  description = "Secrets Manager ARN for AML SFTP private key."
  type        = string
}

variable "create_backend_iam_policy" {
  description = "Whether to create backend access IAM policy."
  type        = bool
  default     = false
}

variable "backend_state_bucket_name" {
  description = "State bucket name for backend access policy."
  type        = string
  default     = ""
}

variable "backend_lock_table_name" {
  description = "Lock table name for backend access policy."
  type        = string
  default     = ""
}

variable "enable_audit_pipeline" {
  description = "Create IAM roles and policies for audit SQS consumer Lambda."
  type        = bool
  default     = false
}

variable "enable_aml_pipeline" {
  description = "Create IAM roles and policies for AML SQS consumer Lambda."
  type        = bool
  default     = false
}

variable "enable_verification_pipeline" {
  description = "Create IAM roles and policies for verification Lambda."
  type        = bool
  default     = false
}

variable "enable_sftp_transaction_collector" {
  description = "Create IAM role and policies for scheduled sftp-transaction-collector Lambda."
  type        = bool
  default     = false
}

variable "audit_sqs_arn" {
  description = "ARN of the audit SQS queue (for Lambda consumer policy)."
  type        = string
  default     = ""
}

variable "audit_dlq_arn" {
  description = "ARN of the audit SQS DLQ (for Lambda consumer policy)."
  type        = string
  default     = ""
}

variable "aml_sqs_arn" {
  description = "ARN of the AML SQS queue (for Lambda consumer policy)."
  type        = string
  default     = ""
}

variable "aml_dlq_arn" {
  description = "ARN of the AML SQS DLQ (for Lambda consumer policy)."
  type        = string
  default     = ""
}

variable "audit_dynamodb_table_arn" {
  description = "ARN of the audit DynamoDB table."
  type        = string
  default     = ""
}

variable "aml_dynamodb_table_arn" {
  description = "ARN of the AML reports DynamoDB table."
  type        = string
  default     = ""
}

variable "verification_bucket_arn" {
  description = "ARN of the verification documents S3 bucket."
  type        = string
  default     = ""
}

variable "verification_sns_topic_arn" {
  description = "ARN of the verification SNS topic."
  type        = string
  default     = ""
}

variable "transaction_sftp_bucket_arn" {
  description = "ARN of the transaction ingestion source S3 bucket (legacy 'sftp' naming)."
  type        = string
  default     = ""
}
