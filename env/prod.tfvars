#--------------------------------------------------
# Production - Terraform Variable Values
#--------------------------------------------------
# Non-sensitive values only.
# Sensitive values must be set via environment variables:
#   export TF_VAR_jwt_hmac_secret="<random-32-chars>"
#   export TF_VAR_root_admin_password="<strong-password-16+chars-upper-lower-digit-symbol>"
#--------------------------------------------------

# --- General ---
environment                    = "prod"
aws_region                     = "ap-southeast-1"
enforce_strict_prod_guardrails = false # budget-first production bring-up profile

# --- Network ---
enable_stateful_service_scale_out = false
enable_multi_az_nat               = false
enable_nat_gateway                = false
enable_vpc_flow_logs              = false

# --- ECS ---
client_desired_count          = 1
ecs_max_capacity              = 2
ecs_use_public_subnets        = true
ecs_assign_public_ip          = true
enable_ecs_container_insights = false

# --- Database ---
db_instance_class                = "db.t4g.micro" # school budget baseline
db_multi_az                      = false
db_backup_retention_days         = 1
db_skip_final_snapshot           = true
db_deletion_protection           = false
db_max_allocated_storage         = 20
rds_performance_insights_enabled = false

# --- Feature Contract (production-like) ---
# Enabled by default for requirement-aligned runtime parity:
# - log API path
# - verification dispatch + feedback path
# - transaction ingestion scheduler path
enable_log_lambda                 = true
enable_sftp_transaction_collector = true
enable_verification_pipeline      = true
ses_sender_email                  = "verification@crm.local" # override with a verified sender in target AWS account

# Intentionally disabled until prerequisites are available:
enable_aml_lambda     = false # requires real SFTP source + key management contract
enable_audit_pipeline = false # implemented but disabled by default in production profile
enable_aml_pipeline   = false # implemented but disabled by default in production profile

# --- Observability & Security ---
enable_waf                    = false
enable_cloudtrail             = false
enable_cloudwatch_alarms      = true
alarm_notification_email      = "crm-alerts-prod@crm.local" # replace with a monitored mailbox before apply
enable_backup                 = true
enable_codedeploy             = true
backup_retention_days         = 30
cloudwatch_log_retention_days = 30

# --- S3 / CloudFront ---
frontend_bucket_force_destroy = false
cloudfront_price_class        = "PriceClass_100"
enable_cloudfront             = true
enable_cloudfront_oac         = true
enable_service_discovery      = true
# Required when app_domain_name is not set and enable_verification_pipeline=true.
# verification_frontend_base_url = "https://<your-frontend-domain>"

# --- Auth ---
enable_cognito            = true
cognito_mfa_configuration = "ON"
auth_mode                 = "hybrid"

# --- Domain / DNS Ownership ---
# Keep custom-domain disabled for first bring-up unless cert + DNS ownership are ready.
# app_domain_name = ""
manage_route53_records            = false
manage_acm_dns_validation_records = false
create_acm_certificates           = false
# route53_hosted_zone_id        = "Z123EXAMPLE"
# existing_frontend_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
# existing_alb_certificate_arn      = "arn:aws:acm:ap-southeast-1:123456789012:certificate/..."
