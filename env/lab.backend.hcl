#--------------------------------------------------
# Learner Lab - Terraform Remote State Backend
#--------------------------------------------------
# IMPORTANT: S3 bucket names are globally unique across ALL AWS accounts.
# Do NOT hardcode a bucket name here — pass it at runtime via terraform init:
#
#   $ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
#   terraform init -backend-config "env/lab.backend.hcl" -backend-config "bucket=scroogebank-crm-lab-tfstate-$ACCOUNT_ID" -reconfigure
#
# The inline -backend-config "bucket=..." overrides any bucket value in this file.
# This file intentionally omits the bucket field so no manual editing is needed.
#
# Prerequisites (create once per Learner Lab account):
#   $ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
#   aws s3api create-bucket --bucket "scroogebank-crm-lab-tfstate-$ACCOUNT_ID" --region us-east-1
#   aws s3api put-bucket-versioning --bucket "scroogebank-crm-lab-tfstate-$ACCOUNT_ID" --versioning-configuration Status=Enabled
#   aws dynamodb create-table --table-name scroogebank-crm-lab-tflock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-1
#   aws dynamodb wait table-exists --table-name scroogebank-crm-lab-tflock --region us-east-1
#--------------------------------------------------
key            = "scroogebank-crm/lab/terraform.tfstate"
region         = "us-east-1"
use_lockfile   = true
encrypt        = true
