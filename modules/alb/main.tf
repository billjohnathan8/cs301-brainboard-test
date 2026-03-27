#--------------------------------------------------------------
# ALB Module
# Internet-facing Application Load Balancer with path-based routing
# to user, client, and transaction ECS services.
#--------------------------------------------------------------

locals {
  # Route groups are ordered by listener-rule priority (lower value = evaluated first).
  # A dedicated exception for `/api/clients/*/transactions*` is defined below with a
  # higher precedence than generic client routes.
  service_routing = {
    user = {
      priority      = 10
      path_patterns = ["/api/auth*", "/api/users*", "/api/v1/users*", "/api/v1/health", "/api/logs*"]
    }
    client = {
      priority      = 20
      path_patterns = ["/api/clients*", "/api/accounts*", "/api/v1/clients*", "/api/communications*", "/api/aml*"]
    }
    transaction = {
      priority      = 30
      path_patterns = ["/api/transactions*"]
    }
  }
}

resource "aws_lb" "crm" {
  name                       = substr("${var.name_prefix}-alb", 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  preserve_host_header       = true
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "service" {
  for_each = local.service_routing

  name        = trim(substr("${var.name_prefix}-${each.key}-tg", 0, 32), "-")
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.service_health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "service_green" {
  for_each = var.enable_blue_green_tg ? local.service_routing : {}

  name        = trim(substr("${var.name_prefix}-${each.key}-tg-green", 0, 32), "-")
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.service_health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.crm.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.use_custom_domain ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.use_custom_domain ? [] : [1]
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "application/json"
        message_body = "{\"message\":\"Not Found\"}"
        status_code  = "404"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.use_custom_domain ? 1 : 0

  load_balancer_arn = aws_lb.crm.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"message\":\"Not Found\"}"
      status_code  = "404"
    }
  }
}

#--------------------------------------------------------------
# Special-case route precedence
# `/api/clients/{clientId}/transactions` belongs to transaction API.
# This must match before generic `/api/clients*` (client service).
#--------------------------------------------------------------
resource "aws_lb_listener_rule" "client_transactions" {
  listener_arn = var.use_custom_domain ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = 15

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service["transaction"].arn
  }

  condition {
    path_pattern {
      values = ["/api/clients/*/transactions*"]
    }
  }
}

resource "aws_lb_listener_rule" "service" {
  for_each = local.service_routing

  listener_arn = var.use_custom_domain ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}
