#--------------------------------------------------------------
# ECS Module - Auto Scaling
# This file configures Application Auto Scaling for ECS services
# Based on CPU and memory utilization metrics
# Stateful services are excluded when enable_stateful_service_scale_out=false.
# Once persistent shared storage is verified, they can be re-included.
#--------------------------------------------------------------

# Auto Scaling targets - define scalable resource
resource "aws_appautoscaling_target" "service" {
  for_each = local.autoscaled_service_configs

  max_capacity       = var.ecs_max_capacity
  min_capacity       = var.ecs_min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU-based auto scaling policy
# Scales out when CPU utilization exceeds target threshold
resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.autoscaled_service_configs

  name               = "${var.name_prefix}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.ecs_target_cpu_utilization
  }
}

# Memory-based auto scaling policy
# Scales out when memory utilization exceeds target threshold
resource "aws_appautoscaling_policy" "memory" {
  for_each = local.autoscaled_service_configs

  name               = "${var.name_prefix}-${each.key}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.ecs_target_memory_utilization
  }
}
