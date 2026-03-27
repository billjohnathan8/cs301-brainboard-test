#--------------------------------------------------
# Learner Lab - Terraform Variable Values
#--------------------------------------------------
# Non-sensitive values only.
# Sensitive values must be set via environment variables:
#   export TF_VAR_jwt_hmac_secret="<random-32-chars>"
#   export TF_VAR_root_admin_password="<strong-password>"
#--------------------------------------------------

# --- General ---
environment = "lab"
aws_region  = "us-east-1"

# --- Network ---
enable_stateful_service_scale_out = false
enable_multi_az_nat               = false # irrelevant when NAT is disabled
enable_nat_gateway                = false # major cost saver for Learner Lab
enable_vpc_flow_logs              = false # avoids extra IAM role churn in first-pass lab deploys

# --- ECS ---
client_desired_count          = 1 # minimal footprint
ecs_max_capacity              = 2
ecs_use_public_subnets        = true
ecs_assign_public_ip          = true
enable_ecs_container_insights = false
enable_service_discovery      = false # LabRole cannot create Cloud Map private DNS namespaces

# --- Database ---
db_instance_class                = "db.t4g.micro"
db_engine_version                = "17"  # explicit; AWS now defaults to 17, parameter group family must match
db_multi_az                      = false # not needed for testing
db_backup_retention_days         = 1
db_skip_final_snapshot           = true  # allow clean teardown
db_deletion_protection           = false # allow clean teardown
db_max_allocated_storage         = 20
rds_performance_insights_enabled = false

# --- Feature Contract (Learner Lab) ---
# Keep runtime-heavy/externally-dependent features disabled in learner-lab.
# Coverage for these paths is provided by local/integration smoke profiles.
enable_log_lambda                 = false # LabRole execution-role path for VPC Lambda is not guaranteed.
enable_aml_lambda                 = false # Requires external SFTP endpoint/key ownership not provided in lab.
enable_sftp_transaction_collector = false # Depends on Lambda + internal auth path that is out of learner-lab scope.
enable_audit_pipeline             = false # Partial scaffold only: runtime artifact absent in repository.
enable_aml_pipeline               = false # Partial scaffold only: runtime artifact absent in repository.
enable_verification_pipeline      = false # Requires SES sender ownership/verification; covered in local/integration.
ses_sender_email                  = ""    # LabRole lacks ses:VerifyEmailIdentity — leave empty to skip aws_ses_email_identity creation.

# --- Observability & Security (reduced for cost) ---
enable_waf                    = false
enable_cloudtrail             = false
enable_cloudwatch_alarms      = false
enable_backup                 = false
cloudwatch_log_retention_days = 7

# --- S3 / CloudFront ---
frontend_bucket_force_destroy = true # allow clean teardown
frontend_bucket_allow_public  = true # S3 static website hosting (no CloudFront in lab)
cloudfront_price_class        = "PriceClass_100"

# --- Auth ---
enable_cognito = false
auth_mode      = "local"

# --- Learner Lab LabRole restrictions ---
# LabRole cannot create IAM roles, CloudFront distributions, or Cloud Map namespaces.
lab_role_name = "LabRole"
# Provide lab_role_arn at runtime via TF_VAR_lab_role_arn (or local helper scripts).
enable_cloudfront     = false
enable_cloudfront_oac = false # moot when enable_cloudfront=false, kept for clarity
enable_codedeploy     = false # CodeDeploy module creates IAM role; disabled under LabRole restrictions

# --- Route53 / ACM ---
manage_route53_records            = false
manage_acm_dns_validation_records = false
create_acm_certificates           = false

# --- Service Docker Image Tags  ---
user_image_tag        = "user-lab-001"
client_image_tag      = "client-lab-001"
transaction_image_tag = "transaction-lab-001"
