#--------------------------------------------------
# Local Contract - Terraform Variable Values
#--------------------------------------------------
# This profile documents the intended local feature contract used by
# LocalStack/container integration runs. It is primarily a contract/plan file;
# local day-to-day execution uses docker-compose + scripts under scripts/ci/.
#--------------------------------------------------

# --- General ---
environment = "local"
aws_region  = "ap-southeast-1"

# --- Network / ECS ---
enable_stateful_service_scale_out = false
enable_multi_az_nat               = false
enable_nat_gateway                = false
enable_vpc_flow_logs              = false
ecs_use_public_subnets            = true
ecs_assign_public_ip              = true
enable_ecs_container_insights     = false
enable_service_discovery          = false # local stack uses Docker DNS, not Cloud Map

# --- Database ---
db_instance_class                = "db.t4g.micro"
db_multi_az                      = false
db_backup_retention_days         = 1
db_skip_final_snapshot           = true
db_deletion_protection           = false
db_max_allocated_storage         = 20
rds_performance_insights_enabled = false

# --- Feature Contract (local) ---
enable_log_lambda                 = true
enable_sftp_transaction_collector = true
enable_verification_pipeline      = true
ses_sender_email                  = "verification@crm.local"

enable_aml_lambda     = false # external SFTP dependency not part of local contract
enable_audit_pipeline = false # implemented but disabled by default in local profile
enable_aml_pipeline   = false # implemented but disabled by default in local profile

# --- Security / Observability ---
enable_waf                    = false
enable_cloudtrail             = false
enable_cloudwatch_alarms      = false
enable_backup                 = false
cloudwatch_log_retention_days = 7

# --- Frontend / Auth ---
enable_cloudfront              = false
enable_cloudfront_oac          = false
frontend_bucket_force_destroy  = true
frontend_bucket_allow_public   = true
verification_frontend_base_url = "http://localhost:18085"
enable_cognito                 = false
auth_mode                      = "local"

# --- Domain / DNS ---
manage_route53_records            = false
manage_acm_dns_validation_records = false
create_acm_certificates           = false
