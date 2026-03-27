#--------------------------------------------------------------
# ECS Module - Outputs
#--------------------------------------------------------------

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "cloudmap_namespace_name" {
  description = "Cloud Map private DNS namespace name."
  value       = local.cloudmap_namespace_name
}

output "client_service_internal_url" {
  description = "Client service internal URL resolved via Cloud Map."
  value       = local.client_service_internal_url
}

output "cloudmap_namespace_id" {
  description = "Cloud Map private DNS namespace ID. Null when service discovery is disabled. Use this to register additional services into the same namespace without a data source lookup."
  value       = var.enable_service_discovery ? aws_service_discovery_private_dns_namespace.internal[0].id : null
}

output "ecs_service_names" {
  description = "ECS service names keyed by logical service key."
  value       = { for service, ecs_service in aws_ecs_service.service : service => ecs_service.name }
}
