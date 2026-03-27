#--------------------------------------------------------------
# ECS Module - Variables
#--------------------------------------------------------------

variable "project_name" {
  description = "Project name used for DNS namespace and parameter path."
  type        = string
}

variable "environment" {
  description = "Environment name used for DNS namespace and parameter path."
  type        = string
}

variable "name_prefix" {
  description = "Global naming prefix for ECS resources."
  type        = string
}

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ECS services are deployed."
  type        = string
}

variable "service_subnet_ids" {
  description = "Subnet IDs used by ECS tasks."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign a public IP address to ECS tasks."
  type        = bool
  default     = false
}

variable "ecs_service_security_group_id" {
  description = "Security group ID attached to ECS services."
  type        = string
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention for ECS service logs."
  type        = number
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights at the cluster level."
  type        = bool
  default     = false
}

variable "target_group_arns" {
  description = "ALB target group ARNs keyed by service name."
  type        = map(string)
}

variable "service_health_check_path" {
  description = "HTTP health endpoint path used for container health checks."
  type        = string
  default     = "/health"
}

variable "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service name."
  type        = map(string)

  validation {
    condition = alltrue([
      contains(keys(var.ecr_repository_urls), "user"),
      contains(keys(var.ecr_repository_urls), "client"),
      contains(keys(var.ecr_repository_urls), "transaction")
    ])
    error_message = "ecr_repository_urls must include user, client, and transaction keys."
  }
}

variable "image_tags" {
  description = "Container image tags per service."
  type = object({
    user        = string
    client      = string
    transaction = string
  })
}

variable "desired_counts" {
  description = "Requested ECS service counts per service. When enable_stateful_service_scale_out is false, user and transaction are pinned to 1 task."
  type = object({
    user        = number
    client      = number
    transaction = number
  })
}

variable "enable_stateful_service_scale_out" {
  description = "Allow user and transaction services to scale beyond one task once persistent shared storage is in place."
  type        = bool
}

variable "ecs_task_cpu" {
  description = "Fargate task CPU units."
  type        = number
}

variable "ecs_task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "ecs_min_capacity" {
  description = "Minimum autoscaling capacity."
  type        = number
}

variable "ecs_max_capacity" {
  description = "Maximum autoscaling capacity."
  type        = number
}

variable "ecs_target_cpu_utilization" {
  description = "Target CPU utilization for autoscaling."
  type        = number
}

variable "ecs_target_memory_utilization" {
  description = "Target memory utilization for autoscaling."
  type        = number
}

variable "ecs_task_execution_role_arn" {
  description = "Execution role ARN used by ECS task definitions."
  type        = string
}

variable "ecs_task_role_arns" {
  description = "Task role ARNs keyed by service name."
  type        = map(string)
}

variable "root_admin_email" {
  description = "Initial root admin email for the user service."
  type        = string
}

variable "auth_mode" {
  description = "Runtime auth mode exposed to backend services (local, hybrid, cognito)."
  type        = string
  default     = "hybrid"
}

variable "cognito_issuer_url" {
  description = "Cognito issuer URL exposed to backend services."
  type        = string
  default     = ""
}

variable "cognito_jwks_url" {
  description = "Cognito JWKS URL exposed to backend services."
  type        = string
  default     = ""
}

variable "cognito_audience" {
  description = "Cognito audience/client ID exposed to backend services."
  type        = string
  default     = ""
}

variable "transaction_mock_sftp_root" {
  description = "MOCK_SFTP_ROOT value for transaction service."
  type        = string
}

variable "transaction_import_s3_bucket" {
  description = "Optional S3 bucket used by transaction service for import source files."
  type        = string
  default     = ""
}

variable "transaction_import_s3_region" {
  description = "AWS region used by transaction service S3 import client."
  type        = string
  default     = "ap-southeast-1"
}

variable "transaction_import_s3_endpoint" {
  description = "Optional endpoint override for transaction service S3 import client."
  type        = string
  default     = ""
}

variable "transaction_import_s3_path_style_access_enabled" {
  description = "Enable path-style addressing for transaction service S3 import client."
  type        = bool
  default     = false
}

variable "enable_service_discovery" {
  description = "Enable AWS Cloud Map private DNS namespace and service discovery for ECS inter-service communication. Disable when LabRole blocks servicediscovery:CreatePrivateDnsNamespace."
  type        = bool
  default     = true
}

variable "alb_dns_name" {
  description = "ALB DNS name used as fallback CLIENT_SERVICE_URL when service discovery is disabled."
  type        = string
  default     = ""
}

variable "db_jdbc_url" {
  description = "JDBC URL consumed by client service."
  type        = string
}

variable "log_api_base_url" {
  description = "Log API base URL consumed by client service."
  type        = string
}

variable "verification_email_provider" {
  description = "Verification email provider for client service (mock or ses)."
  type        = string
  default     = "mock"
}

variable "ses_sender_email" {
  description = "SES sender email passed to client service for verification notifications."
  type        = string
  default     = ""
}

variable "verification_sns_topic_arn" {
  description = "SNS topic ARN used by client service to publish verification email requests."
  type        = string
  default     = ""
}

variable "verification_documents_bucket" {
  description = "S3 bucket name used by client service for verification document uploads."
  type        = string
  default     = ""
}

variable "root_admin_password_secret_arn" {
  description = "Secret ARN for ROOT_ADMIN_PASSWORD."
  type        = string
}

variable "jwt_hmac_secret_arn" {
  description = "Secret ARN for JWT_HMAC_SECRET."
  type        = string
}

variable "db_username_secret_arn" {
  description = "Secret ARN for SPRING_DATASOURCE_USERNAME."
  type        = string
}

variable "db_password_secret_arn" {
  description = "Secret ARN for SPRING_DATASOURCE_PASSWORD."
  type        = string
}

variable "use_codedeploy_controller" {
  description = "Use CODE_DEPLOY deployment controller for ECS services instead of the default ECS rolling-update controller. Required for CodeDeploy blue/green deployments. WARNING: changing this on an existing service forces service recreation."
  type        = bool
  default     = false
}

variable "enable_deployment_alarms" {
  description = "Enable ECS deployment alarms for CloudWatch-based failed deployment detection and rollback."
  type        = bool
  default     = false
}

variable "deployment_alarm_names" {
  description = "CloudWatch alarm names per service to evaluate during ECS deployments. Keys must match service names (user, client, transaction)."
  type        = map(list(string))
  default     = {}
}
