#--------------------------------------------------------------
# Cognito Module - Outputs
#--------------------------------------------------------------

output "user_pool_id" {
  description = "Cognito User Pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN."
  value       = aws_cognito_user_pool.this.arn
}

output "app_client_id" {
  description = "Cognito App Client ID."
  value       = aws_cognito_user_pool_client.this.id
}

output "user_pool_endpoint" {
  description = "Cognito User Pool endpoint for authentication."
  value       = aws_cognito_user_pool.this.endpoint
}

output "jwks_url" {
  description = "JWKS URL for verifying JWT tokens."
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}/.well-known/jwks.json"
}

output "issuer_url" {
  description = "Issuer URL for JWT verification."
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}

output "admin_group_name" {
  description = "Name of the admin user group."
  value       = aws_cognito_user_group.admin.name
}

output "user_group_name" {
  description = "Name of the user role group."
  value       = aws_cognito_user_group.user.name
}
