#--------------------------------------------------------------
# SNS Module - Amazon Simple Notification Service
# This module manages SNS topics for pub/sub messaging
# Supports fan-out patterns and multi-subscriber notifications
#--------------------------------------------------------------

# Verification & Notification Topic
# Publishes verification events and notifications to subscribed endpoints
# Can be configured with email subscriptions for alerts
resource "aws_sns_topic" "verification" {
  count = var.enable_verification_pipeline ? 1 : 0

  name = "${var.name_prefix}-verification"

  tags = {
    Name        = "${var.name_prefix}-verification"
    Environment = var.environment
    Service     = "verification"
    ManagedBy   = "terraform"
  }
}

# SNS Email Subscription for verification notifications
# Subscribes an email endpoint to receive verification alerts
# Note: Subscription confirmation email is sent to the endpoint
resource "aws_sns_topic_subscription" "verification_email" {
  count = var.enable_verification_pipeline && var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.verification[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch alarm notification topic.
resource "aws_sns_topic" "alarm_notifications" {
  count = var.enable_alarm_topic ? 1 : 0

  name = "${var.name_prefix}-alarms"

  tags = {
    Name        = "${var.name_prefix}-alarms"
    Environment = var.environment
    Service     = "observability"
    ManagedBy   = "terraform"
  }
}

# SNS Email subscription for CloudWatch alarm notifications.
resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.enable_alarm_topic && var.alarm_notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarm_notifications[0].arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}
