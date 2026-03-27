#--------------------------------------------------------------
# WAF Module - Outputs
#--------------------------------------------------------------

output "waf_arn" {
  description = "WAF ARN for CloudFront attachment."
  value       = var.enable_waf ? aws_wafv2_web_acl.frontend[0].arn : null
}
