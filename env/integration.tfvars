#--------------------------------------------------
# Integration Contract - Terraform Variable Values
#--------------------------------------------------
# This profile is for the shared integration environment.
# It keeps cost-sensitive infrastructure lean while enabling core
# project-required runtime features for end-to-end validation.
#--------------------------------------------------

# --- General ---
environment = "integration"
aws_region  = "ap-southeast-1"

# --- Network / ECS ---
enable_stateful_service_scale_out = false
enable_multi_az_nat               = false
enable_nat_gateway                = false
enable_vpc_flow_logs              = false
ecs_use_public_subnets            = true
ecs_assign_public_ip              = true
enable_ecs_container_insights     = false
enable_service_discovery          = true

# --- Database ---
db_instance_class                = "db.t4g.micro"
db_multi_az                      = false
db_backup_retention_days         = 1
db_skip_final_snapshot           = true
db_deletion_protection           = false
db_max_allocated_storage         = 20
rds_performance_insights_enabled = false

# --- Feature Contract (integration) ---
enable_log_lambda                 = true
enable_sftp_transaction_collector = true
enable_verification_pipeline      = true
ses_sender_email                  = "verification@crm.local" # replace with a verified sender in real AWS integration

enable_aml_lambda     = false # requires real SFTP endpoint + key ownership contract
enable_audit_pipeline = false # implemented but disabled by default in integration profile
enable_aml_pipeline   = false # implemented but disabled by default in integration profile

# --- Security / Observability ---
enable_waf                    = false
enable_cloudtrail             = false
enable_cloudwatch_alarms      = true
alarm_notification_email      = "crm-alerts-integration@crm.local" # replace with a monitored mailbox before apply
enable_backup                 = false
cloudwatch_log_retention_days = 7

# --- Frontend / Auth ---
enable_cloudfront         = true
enable_cloudfront_oac     = true
enable_cognito            = true
cognito_mfa_configuration = "OPTIONAL"
auth_mode                 = "hybrid"
cloudfront_price_class    = "PriceClass_100"
# Required when app_domain_name is not set and enable_verification_pipeline=true.
# verification_frontend_base_url = "https://<your-frontend-domain>"

# --- Domain / DNS ---
manage_route53_records            = false
manage_acm_dns_validation_records = false
create_acm_certificates           = false
