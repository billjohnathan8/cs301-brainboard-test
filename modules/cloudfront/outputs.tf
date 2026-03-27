#--------------------------------------------------------------
# CloudFront Module - Outputs
#--------------------------------------------------------------

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "CloudFront hosted zone ID."
  value       = aws_cloudfront_distribution.frontend.hosted_zone_id
}

output "app_url" {
  description = "Primary app URL."
  value       = var.use_custom_domain ? "https://${var.app_domain_name}" : "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_dns_record_fqdn" {
  description = "Fully qualified domain name of the CloudFront DNS record (if created)."
  value       = length(aws_route53_record.cloudfront) > 0 ? aws_route53_record.cloudfront[0].fqdn : null
}
