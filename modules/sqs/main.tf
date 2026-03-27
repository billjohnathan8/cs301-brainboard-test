#--------------------------------------------------------------
# SQS Module - Amazon Simple Queue Service
# This module manages SQS queues for asynchronous message processing
# Includes main queues and Dead Letter Queues (DLQ) for failed messages
#--------------------------------------------------------------

# Audit Logging Pipeline - Dead Letter Queue
# Captures failed messages from the audit queue for investigation
resource "aws_sqs_queue" "audit_dlq" {
  count = var.enable_audit_pipeline ? 1 : 0

  name                      = "${var.name_prefix}-audit-dlq"
  message_retention_seconds = var.dlq_retention_seconds

  tags = {
    Name        = "${var.name_prefix}-audit-dlq"
    Environment = var.environment
    Service     = "audit"
    ManagedBy   = "terraform"
  }
}

# Audit Logging Pipeline - Main Queue
# Receives audit log events from ECS services for async processing
resource "aws_sqs_queue" "audit" {
  count = var.enable_audit_pipeline ? 1 : 0

  name                       = "${var.name_prefix}-audit-queue"
  visibility_timeout_seconds = var.audit_visibility_timeout
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.audit_dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name        = "${var.name_prefix}-audit-queue"
    Environment = var.environment
    Service     = "audit"
    ManagedBy   = "terraform"
  }
}

# AML Processing Pipeline - Dead Letter Queue
# Captures failed messages from the AML queue for investigation
resource "aws_sqs_queue" "aml_dlq" {
  count = var.enable_aml_pipeline ? 1 : 0

  name                      = "${var.name_prefix}-aml-dlq"
  message_retention_seconds = var.dlq_retention_seconds

  tags = {
    Name        = "${var.name_prefix}-aml-dlq"
    Environment = var.environment
    Service     = "aml"
    ManagedBy   = "terraform"
  }
}

# AML Processing Pipeline - Main Queue
# Receives AML (Anti-Money Laundering) events for compliance processing
resource "aws_sqs_queue" "aml" {
  count = var.enable_aml_pipeline ? 1 : 0

  name                       = "${var.name_prefix}-aml-queue"
  visibility_timeout_seconds = var.aml_visibility_timeout
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.aml_dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name        = "${var.name_prefix}-aml-queue"
    Environment = var.environment
    Service     = "aml"
    ManagedBy   = "terraform"
  }
}
