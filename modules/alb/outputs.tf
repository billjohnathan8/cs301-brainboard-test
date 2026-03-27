#--------------------------------------------------------------
# ALB Module - Outputs
#--------------------------------------------------------------

output "alb_dns_name" {
  description = "ALB DNS name for backend ingress."
  value       = aws_lb.crm.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID."
  value       = aws_lb.crm.zone_id
}

output "target_group_arns" {
  description = "ALB target group ARNs keyed by service name."
  value       = { for service, target_group in aws_lb_target_group.service : service => target_group.arn }
}

output "target_group_names" {
  description = "ALB primary target group names keyed by service name."
  value       = { for service, target_group in aws_lb_target_group.service : service => target_group.name }
}

output "target_group_green_names" {
  description = "ALB green target group names keyed by service name for CodeDeploy blue/green deployments."
  value       = { for service, target_group in aws_lb_target_group.service_green : service => target_group.name }
}

output "primary_listener_arn" {
  description = "Primary ALB listener ARN used for production traffic."
  value       = var.use_custom_domain ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch alarm dimensions."
  value       = aws_lb.crm.arn_suffix
}

output "alb_dns_record_fqdn" {
  description = "Fully qualified domain name of the ALB DNS record (if created)."
  value       = length(aws_route53_record.alb) > 0 ? aws_route53_record.alb[0].fqdn : null
}

output "target_group_arn_suffixes" {
  description = "ALB target group ARN suffixes keyed by service name."
  value       = { for service, tg in aws_lb_target_group.service : service => tg.arn_suffix }
}
