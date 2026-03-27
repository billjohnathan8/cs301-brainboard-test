#--------------------------------------------------------------
# API Gateway Module - Outputs
#--------------------------------------------------------------

output "log_api_base_url" {
  description = "API Gateway endpoint URL."
  value       = aws_apigatewayv2_api.log.api_endpoint
}

output "log_api_origin_domain_name" {
  description = "API Gateway origin domain for CloudFront."
  value       = trimsuffix(trimprefix(aws_apigatewayv2_api.log.api_endpoint, "https://"), "/")
}
