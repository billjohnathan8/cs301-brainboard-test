#--------------------------------------------------------------
# ECR Module - Outputs
#--------------------------------------------------------------

output "repository_url" {
  description = "Compatibility output for the user service ECR repository URL."
  value       = aws_ecr_repository.service["user"].repository_url
}

output "repository_name" {
  description = "Compatibility output for the user service ECR repository name."
  value       = aws_ecr_repository.service["user"].name
}

output "repository_urls" {
  description = "ECR repository URLs keyed by service name."
  value       = { for service, repo in aws_ecr_repository.service : service => repo.repository_url }
}

output "repository_names" {
  description = "ECR repository names keyed by service name."
  value       = { for service, repo in aws_ecr_repository.service : service => repo.name }
}
