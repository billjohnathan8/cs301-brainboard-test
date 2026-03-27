#--------------------------------------------------
# Integration - Terraform Remote State Backend
#--------------------------------------------------
# Prerequisites (create once manually in integration AWS account):
#   aws s3api create-bucket --bucket scroogebank-crm-integration-tfstate \
#     --region ap-southeast-1 \
#     --create-bucket-configuration LocationConstraint=ap-southeast-1
#   aws s3api put-bucket-versioning --bucket scroogebank-crm-integration-tfstate \
#     --versioning-configuration Status=Enabled
#   aws dynamodb create-table --table-name scroogebank-crm-integration-tflock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region ap-southeast-1
#--------------------------------------------------

bucket         = "scroogebank-crm-integration-tfstate"
key            = "scroogebank-crm/integration/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "scroogebank-crm-integration-tflock"
encrypt        = true
