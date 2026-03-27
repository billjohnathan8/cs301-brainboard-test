#--------------------------------------------------------------
# CodeDeploy Module
# Creates deployment applications/groups for ECS services and Lambda functions.
#--------------------------------------------------------------

locals {
  lambda_enabled_deployments = {
    for service, cfg in var.lambda_deployments :
    service => cfg
    if cfg.enabled && trimspace(cfg.function_name) != "" && trimspace(cfg.alias_name) != ""
  }
}

resource "aws_iam_role" "codedeploy" {
  count = var.enable_codedeploy ? 1 : 0

  name = "${var.name_prefix}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  count = var.enable_codedeploy ? 1 : 0

  role       = aws_iam_role.codedeploy[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_iam_role_policy_attachment" "codedeploy_lambda" {
  count = var.enable_codedeploy ? 1 : 0

  role       = aws_iam_role.codedeploy[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

resource "aws_codedeploy_app" "ecs" {
  count = var.enable_codedeploy ? 1 : 0

  name             = "${var.name_prefix}-ecs"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "ecs" {
  for_each = var.enable_codedeploy ? var.ecs_service_names : {}

  app_name               = aws_codedeploy_app.ecs[0].name
  deployment_group_name  = "${var.name_prefix}-${each.key}-ecs"
  service_role_arn       = aws_iam_role.codedeploy[0].arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM", "DEPLOYMENT_STOP_ON_REQUEST"]
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = each.value
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.alb_listener_arn]
      }

      target_group {
        name = var.ecs_blue_target_group_names[each.key]
      }

      target_group {
        name = var.ecs_green_target_group_names[each.key]
      }
    }
  }
}

resource "aws_codedeploy_app" "lambda" {
  count = var.enable_codedeploy ? 1 : 0

  name             = "${var.name_prefix}-lambda"
  compute_platform = "Lambda"
}

resource "aws_codedeploy_deployment_group" "lambda" {
  for_each = var.enable_codedeploy ? local.lambda_enabled_deployments : {}

  app_name               = aws_codedeploy_app.lambda[0].name
  deployment_group_name  = "${var.name_prefix}-${each.key}-lambda"
  service_role_arn       = aws_iam_role.codedeploy[0].arn
  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM", "DEPLOYMENT_STOP_ON_REQUEST"]
  }
}
