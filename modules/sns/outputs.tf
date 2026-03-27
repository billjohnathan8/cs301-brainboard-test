#--------------------------------------------------------------
# SNS Module - Outputs
#--------------------------------------------------------------

output "verification_topic_arn" {
  description = "Verification SNS topic ARN."
  value       = var.enable_verification_pipeline ? aws_sns_topic.verification[0].arn : ""
}

output "verification_topic_name" {
  description = "Verification SNS topic name."
  value       = var.enable_verification_pipeline ? aws_sns_topic.verification[0].name : ""
}

output "alarm_topic_arn" {
  description = "CloudWatch alarm notification SNS topic ARN."
  value       = var.enable_alarm_topic ? aws_sns_topic.alarm_notifications[0].arn : ""
}

output "alarm_topic_name" {
  description = "CloudWatch alarm notification SNS topic name."
  value       = var.enable_alarm_topic ? aws_sns_topic.alarm_notifications[0].name : ""
}
