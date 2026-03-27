#--------------------------------------------------------------
# CodeDeploy Module - Outputs
#--------------------------------------------------------------

output "ecs_application_name" {
  description = "CodeDeploy application name for ECS deployments."
  value       = var.enable_codedeploy ? aws_codedeploy_app.ecs[0].name : null
}

output "lambda_application_name" {
  description = "CodeDeploy application name for Lambda deployments."
  value       = var.enable_codedeploy ? aws_codedeploy_app.lambda[0].name : null
}

output "ecs_deployment_group_names" {
  description = "CodeDeploy deployment group names keyed by ECS service."
  value       = { for service, group in aws_codedeploy_deployment_group.ecs : service => group.deployment_group_name }
}

output "lambda_deployment_group_names" {
  description = "CodeDeploy deployment group names keyed by Lambda logical service."
  value       = { for service, group in aws_codedeploy_deployment_group.lambda : service => group.deployment_group_name }
}
