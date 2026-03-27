#--------------------------------------------------------------
# CodeDeploy Module - Variables
#--------------------------------------------------------------

variable "enable_codedeploy" {
  description = "Whether to provision CodeDeploy applications and deployment groups."
  type        = bool
}

variable "name_prefix" {
  description = "Global naming prefix."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for ECS deployment groups."
  type        = string
}

variable "ecs_service_names" {
  description = "ECS service names keyed by logical service key."
  type        = map(string)
}

variable "alb_listener_arn" {
  description = "ALB listener ARN used for production traffic shifting."
  type        = string
}

variable "ecs_blue_target_group_names" {
  description = "Primary ALB target group names keyed by service name."
  type        = map(string)
}

variable "ecs_green_target_group_names" {
  description = "Green ALB target group names keyed by service name."
  type        = map(string)
}

variable "lambda_deployments" {
  description = "Lambda deployment descriptors keyed by logical service name."
  type = map(object({
    enabled       = bool
    function_name = string
    alias_name    = string
  }))
}
