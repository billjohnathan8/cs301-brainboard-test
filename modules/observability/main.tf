#--------------------------------------------------------------
# Observability Module
# CloudTrail, CloudWatch alarms, and SNS alerting for
# infrastructure monitoring and compliance audit trails.
#--------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  alarm_action_arns = trimspace(var.alarm_notification_topic_arn) == "" ? [] : [trimspace(var.alarm_notification_topic_arn)]
}

# --- CloudTrail ---

resource "aws_s3_bucket" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket        = "${var.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.cloudtrail_bucket_force_destroy

  tags = {
    Name = "${var.name_prefix}-cloudtrail"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket                  = aws_s3_bucket.cloudtrail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudtrail" "this" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  tags = {
    Name = "${var.name_prefix}-trail"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# --- CloudWatch Alarms ---

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = var.enable_ecs_alarms ? var.ecs_service_names : toset([])

  alarm_name          = "${var.name_prefix}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_cpu_alarm_threshold
  alarm_description   = "ECS ${each.key} CPU utilization above ${var.ecs_cpu_alarm_threshold}%"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = "${var.name_prefix}-${each.key}"
  }

  tags = {
    Name = "${var.name_prefix}-${each.key}-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_alarm_threshold
  alarm_description   = "RDS CPU utilization above ${var.rds_cpu_alarm_threshold}%"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }

  tags = {
    Name = "${var.name_prefix}-rds-cpu-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  count = var.enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_free_storage_threshold_bytes
  alarm_description   = "RDS free storage below threshold"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }

  tags = {
    Name = "${var.name_prefix}-rds-low-storage"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_alarm_threshold
  alarm_description   = "ALB 5XX errors above threshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name = "${var.name_prefix}-alb-5xx-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate_high" {
  count = var.enable_ses_alarms && var.ses_identity != "" ? 1 : 0

  alarm_name          = "${var.name_prefix}-ses-bounce-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.BounceRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = var.ses_bounce_rate_alarm_threshold
  alarm_description   = "SES bounce rate above threshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    Identity = var.ses_identity
  }

  tags = {
    Name = "${var.name_prefix}-ses-bounce-rate-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate_high" {
  count = var.enable_ses_alarms && var.ses_identity != "" ? 1 : 0

  alarm_name          = "${var.name_prefix}-ses-complaint-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.ComplaintRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = var.ses_complaint_rate_alarm_threshold
  alarm_description   = "SES complaint rate above threshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    Identity = var.ses_identity
  }

  tags = {
    Name = "${var.name_prefix}-ses-complaint-rate-high"
  }
}

# --- ECS Memory Utilization Alarms ---

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  for_each = var.enable_ecs_alarms ? var.ecs_service_names : toset([])

  alarm_name          = "${var.name_prefix}-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_memory_alarm_threshold
  alarm_description   = "ECS ${each.key} memory utilization above ${var.ecs_memory_alarm_threshold}%"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = "${var.name_prefix}-${each.key}"
  }

  tags = {
    Name = "${var.name_prefix}-${each.key}-memory-high"
  }
}

# --- ECS Running Task Count Alarms ---
# Detects service outages where all tasks have stopped.
# Uses ECS/ContainerInsights namespace (requires Container Insights enabled on cluster).

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  for_each = var.enable_ecs_alarms ? var.ecs_service_names : toset([])

  alarm_name          = "${var.name_prefix}-${each.key}-running-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ECS ${each.key} has fewer than 1 running task"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = "${var.name_prefix}-${each.key}"
  }

  tags = {
    Name = "${var.name_prefix}-${each.key}-running-tasks-low"
  }
}

# --- ALB Per-Target-Group Alarms ---
# Unhealthy host count, target-originated 5XX errors, and response time.

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  for_each = var.enable_alb_alarms ? var.target_group_arn_suffixes : {}

  alarm_name          = "${var.name_prefix}-${each.key}-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.alb_unhealthy_host_threshold
  alarm_description   = "ALB target group ${each.key} has ${var.alb_unhealthy_host_threshold} or more unhealthy hosts"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = each.value
  }

  tags = {
    Name = "${var.name_prefix}-${each.key}-unhealthy-hosts"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  for_each = var.enable_alb_alarms ? var.target_group_arn_suffixes : {}

  alarm_name          = "${var.name_prefix}-${each.key}-target-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_target_5xx_threshold
  alarm_description   = "ALB target group ${each.key} target-originated 5XX errors above ${var.alb_target_5xx_threshold}"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = each.value
  }

  tags = {
    Name = "${var.name_prefix}-${each.key}-target-5xx-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  for_each = var.enable_alb_alarms ? var.target_group_arn_suffixes : {}

  alarm_name          = "${var.name_prefix}-${each.key}-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.alb_response_time_threshold
  alarm_description   = "ALB target group ${each.key} average response time above ${var.alb_response_time_threshold}s"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  ok_actions          = local.alarm_action_arns

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = each.value
  }

  tags = {
    Name = "${var.name_prefix}-${each.key}-response-time-high"
  }
}

# --- CloudWatch Dashboard ---
# Consolidated view of ECS service health and ALB traffic metrics.

resource "aws_cloudwatch_dashboard" "main" {
  count = var.enable_dashboard ? 1 : 0

  dashboard_name = "${var.name_prefix}-ecs-alb"

  dashboard_body = jsonencode({
    widgets = concat(
      # Row 1: ECS service metrics
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 8
          height = 6
          properties = {
            title   = "ECS CPU Utilization (%)"
            metrics = [for svc in var.ecs_service_names : ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", "${var.name_prefix}-${svc}"]]
            period  = 300
            stat    = "Average"
            region  = var.aws_region
            yAxis   = { left = { min = 0, max = 100 } }
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 0
          width  = 8
          height = 6
          properties = {
            title   = "ECS Memory Utilization (%)"
            metrics = [for svc in var.ecs_service_names : ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", "${var.name_prefix}-${svc}"]]
            period  = 300
            stat    = "Average"
            region  = var.aws_region
            yAxis   = { left = { min = 0, max = 100 } }
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 0
          width  = 8
          height = 6
          properties = {
            title   = "ECS Running Task Count"
            metrics = [for svc in var.ecs_service_names : ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", "${var.name_prefix}-${svc}"]]
            period  = 60
            stat    = "Average"
            region  = var.aws_region
            yAxis   = { left = { min = 0 } }
          }
        },
      ],
      # Row 2: ALB traffic metrics
      [
        {
          type   = "metric"
          x      = 0
          y      = 6
          width  = 8
          height = 6
          properties = {
            title = "ALB Request Count"
            metrics = [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }]
            ]
            period = 300
            region = var.aws_region
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 6
          width  = 8
          height = 6
          properties = {
            title = "ALB HTTP Response Codes"
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "Target 2XX" }],
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "Target 4XX" }],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "Target 5XX" }],
              ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "ELB 5XX" }]
            ]
            period = 300
            region = var.aws_region
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 6
          width  = 8
          height = 6
          properties = {
            title = "ALB Target Response Time (s)"
            metrics = [
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "Avg" }],
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p99", label = "p99" }]
            ]
            period = 300
            region = var.aws_region
          }
        },
      ],
      # Row 3: Per-target-group host health
      [
        {
          type   = "metric"
          x      = 0
          y      = 12
          width  = 12
          height = 6
          properties = {
            title   = "ALB Healthy Host Count"
            metrics = [for svc, suffix in var.target_group_arn_suffixes : ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", suffix, "LoadBalancer", var.alb_arn_suffix, { label = svc }]]
            period  = 60
            stat    = "Average"
            region  = var.aws_region
            yAxis   = { left = { min = 0 } }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 12
          width  = 12
          height = 6
          properties = {
            title   = "ALB Unhealthy Host Count"
            metrics = [for svc, suffix in var.target_group_arn_suffixes : ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", suffix, "LoadBalancer", var.alb_arn_suffix, { label = svc }]]
            period  = 60
            stat    = "Average"
            region  = var.aws_region
            yAxis   = { left = { min = 0 } }
          }
        },
      ]
    )
  })
}
