#--------------------------------------------------------------
# ECS Module - Task Definitions and Services
# This file defines ECS task definitions and services for
# running containerized applications on Fargate
#--------------------------------------------------------------

# ECS Task Definitions - define container specifications
resource "aws_ecs_task_definition" "service" {
  for_each = local.service_configs

  family                   = "${var.name_prefix}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.ecs_task_cpu)
  memory                   = tostring(var.ecs_task_memory)
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arns[each.key]

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${var.ecr_repository_urls[each.key]}:${each.value.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = each.value.environment
      secrets     = each.value.secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:8080${var.service_health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])
}

# ECS Services - manage running tasks and integrate with ALB
resource "aws_ecs_service" "service" {
  for_each = local.service_configs

  name        = "${var.name_prefix}-${each.key}"
  cluster     = aws_ecs_cluster.this.id
  launch_type = "FARGATE"
  # desired_count already reflects statefulness rules from local.service_configs.
  desired_count                      = each.value.desired_count
  task_definition                    = aws_ecs_task_definition.service[each.key].arn
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = var.use_codedeploy_controller ? null : 50
  deployment_maximum_percent         = var.use_codedeploy_controller ? null : 200

  # CODE_DEPLOY controller enables CodeDeploy blue/green deployments.
  # Default ECS controller uses rolling updates.
  dynamic "deployment_controller" {
    for_each = var.use_codedeploy_controller ? [1] : []
    content {
      type = "CODE_DEPLOY"
    }
  }

  # Circuit breaker for automatic rollback on failed deployments.
  # Only compatible with the default ECS (rolling-update) controller.
  dynamic "deployment_circuit_breaker" {
    for_each = var.use_codedeploy_controller ? [] : [1]
    content {
      enable   = true
      rollback = true
    }
  }

  # CloudWatch alarm-based deployment monitoring (complements circuit breaker).
  # Only compatible with the default ECS controller.
  dynamic "alarms" {
    for_each = !var.use_codedeploy_controller && var.enable_deployment_alarms && contains(keys(var.deployment_alarm_names), each.key) ? [1] : []
    content {
      alarm_names = var.deployment_alarm_names[each.key]
      enable      = true
      rollback    = true
    }
  }

  # Network configuration for Fargate tasks
  network_configuration {
    subnets          = var.service_subnet_ids
    security_groups  = [var.ecs_service_security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  # Load balancer integration
  load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = each.key
    container_port   = 8080
  }

  # Service discovery registration (disabled when Cloud Map is not available)
  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []
    content {
      registry_arn   = aws_service_discovery_service.service[each.key].arn
      container_name = each.key
      container_port = 8080
    }
  }
}

# SSM Parameter for client service internal URL
resource "aws_ssm_parameter" "client_service_url" {
  name  = "/${var.project_name}/${var.environment}/service/client/internal_url"
  type  = "String"
  value = local.client_service_internal_url

  lifecycle {
    precondition {
      condition     = var.enable_service_discovery || var.alb_dns_name != ""
      error_message = "alb_dns_name must be provided when enable_service_discovery is false; CLIENT_SERVICE_URL would otherwise be empty."
    }
  }
}
