#--------------------------------------------------------------
# ECS Module - Main Configuration
# This file contains local variables and the ECS cluster definition
#--------------------------------------------------------------

# Service-specific configurations including desired count, image tags,
# environment variables, and secrets
locals {
  # Services that require strict single-replica safety when stateful scale-out
  # is disabled. Toggle via enable_stateful_service_scale_out.
  in_memory_stateful_services = toset(["user", "transaction"])

  requested_desired_counts = {
    user        = var.desired_counts.user
    client      = var.desired_counts.client
    transaction = var.desired_counts.transaction
  }

  effective_desired_counts = merge(
    local.requested_desired_counts,
    var.enable_stateful_service_scale_out ? {} : {
      for service_name in local.in_memory_stateful_services : service_name => 1
    }
  )

  service_configs = {
    user = {
      desired_count = local.effective_desired_counts.user
      image_tag     = var.image_tags.user
      environment = [
        {
          name  = "ROOT_ADMIN_EMAIL"
          value = var.root_admin_email
        },
        {
          name  = "SPRING_DATASOURCE_URL"
          value = var.db_jdbc_url
        },
        {
          name  = "APP_USER_STORE_TYPE"
          value = "postgres"
        },
        {
          name  = "AUTH_MODE"
          value = var.auth_mode
        },
        {
          name  = "COGNITO_ISSUER"
          value = var.cognito_issuer_url
        },
        {
          name  = "COGNITO_JWKS_URL"
          value = var.cognito_jwks_url
        },
        {
          name  = "COGNITO_AUDIENCE"
          value = var.cognito_audience
        }
      ]
      secrets = [
        {
          name      = "ROOT_ADMIN_PASSWORD"
          valueFrom = var.root_admin_password_secret_arn
        },
        {
          name      = "JWT_HMAC_SECRET"
          valueFrom = var.jwt_hmac_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = var.db_username_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.db_password_secret_arn
        }
      ]
    }
    client = {
      desired_count = local.effective_desired_counts.client
      image_tag     = var.image_tags.client
      environment = [
        {
          name  = "SPRING_DATASOURCE_URL"
          value = var.db_jdbc_url
        },
        {
          name  = "CLIENT_LOG_SERVICE_URL"
          value = var.log_api_base_url
        },
        {
          name  = "VERIFICATION_EMAIL_PROVIDER"
          value = var.verification_email_provider
        },
        {
          name  = "SES_SENDER_EMAIL"
          value = var.ses_sender_email
        },
        {
          name  = "VERIFICATION_SNS_TOPIC_ARN"
          value = var.verification_sns_topic_arn
        },
        {
          name  = "VERIFICATION_DOCUMENTS_BUCKET"
          value = var.verification_documents_bucket
        },
        {
          name  = "VERIFICATION_EMAIL_AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "AUTH_MODE"
          value = var.auth_mode
        },
        {
          name  = "COGNITO_ISSUER"
          value = var.cognito_issuer_url
        },
        {
          name  = "COGNITO_JWKS_URL"
          value = var.cognito_jwks_url
        },
        {
          name  = "COGNITO_AUDIENCE"
          value = var.cognito_audience
        }
      ]
      secrets = [
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = var.db_username_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.db_password_secret_arn
        },
        {
          name      = "JWT_HMAC_SECRET"
          valueFrom = var.jwt_hmac_secret_arn
        }
      ]
    }
    transaction = {
      desired_count = local.effective_desired_counts.transaction
      image_tag     = var.image_tags.transaction
      environment = [
        {
          name  = "CLIENT_SERVICE_URL"
          value = local.client_service_internal_url
        },
        {
          name  = "MOCK_SFTP_ROOT"
          value = var.transaction_mock_sftp_root
        },
        {
          name  = "SPRING_DATASOURCE_URL"
          value = var.db_jdbc_url
        },
        {
          name  = "APP_TRANSACTIONS_STORE_TYPE"
          value = "postgres"
        },
        {
          name  = "TRANSACTION_IMPORT_S3_BUCKET"
          value = var.transaction_import_s3_bucket
        },
        {
          name  = "TRANSACTION_IMPORT_S3_REGION"
          value = var.transaction_import_s3_region
        },
        {
          name  = "TRANSACTION_IMPORT_S3_ENDPOINT"
          value = var.transaction_import_s3_endpoint
        },
        {
          name  = "TRANSACTION_IMPORT_S3_PATH_STYLE_ACCESS_ENABLED"
          value = tostring(var.transaction_import_s3_path_style_access_enabled)
        },
        {
          name  = "AUTH_MODE"
          value = var.auth_mode
        },
        {
          name  = "COGNITO_ISSUER"
          value = var.cognito_issuer_url
        },
        {
          name  = "COGNITO_JWKS_URL"
          value = var.cognito_jwks_url
        },
        {
          name  = "COGNITO_AUDIENCE"
          value = var.cognito_audience
        }
      ]
      secrets = [
        {
          name      = "JWT_HMAC_SECRET"
          valueFrom = var.jwt_hmac_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = var.db_username_secret_arn
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = var.db_password_secret_arn
        }
      ]
    }
  }

  autoscaled_service_configs = {
    for service_name, config in local.service_configs :
    service_name => config
    if var.enable_stateful_service_scale_out || !contains(local.in_memory_stateful_services, service_name)
  }

  # CloudMap namespace for service discovery.
  # Derived from the resource attribute when discovery is on so that any change
  # to the namespace name propagates automatically rather than silently diverging.
  cloudmap_namespace_name     = var.enable_service_discovery ? aws_service_discovery_private_dns_namespace.internal[0].name : "${var.environment}.${var.project_name}.internal"
  client_service_internal_url = var.enable_service_discovery ? "http://client.${local.cloudmap_namespace_name}:8080" : "http://${var.alb_dns_name}"
}

# ECS Cluster with Container Insights enabled for monitoring
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-ecs"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }
}
