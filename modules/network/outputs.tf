#--------------------------------------------------------------
# Network Module - Outputs
#--------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = [for idx in sort(keys(local.public_subnet_map)) : aws_subnet.public[idx].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = [for idx in sort(keys(local.private_subnet_map)) : aws_subnet.private[idx].id]
}

output "db_subnet_ids" {
  description = "Database subnet IDs. Empty if db_subnet_cidrs is not provided."
  value       = [for idx in sort(keys(local.db_subnet_map)) : aws_subnet.db[idx].id]
}
