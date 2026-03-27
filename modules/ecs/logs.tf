#--------------------------------------------------------------
# ECS Module - CloudWatch Logs
# This file configures CloudWatch Log Groups for ECS container logs
# Provides centralized logging for troubleshooting and monitoring
#--------------------------------------------------------------

# CloudWatch Log Groups for each ECS service
# Container logs are automatically streamed here
resource "aws_cloudwatch_log_group" "ecs" {
  for_each = local.service_configs

  name              = "/aws/ecs/${var.name_prefix}/${each.key}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name        = "${var.name_prefix}-${each.key}-logs"
    Service     = each.key
    Environment = var.environment
  }
}
