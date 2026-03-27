#--------------------------------------------------
# Production - Terraform Remote State Backend
#--------------------------------------------------
# Prerequisites (create once manually in the school-assigned AWS account):
#   aws s3api create-bucket --bucket scroogebank-crm-prod-tfstate \
#     --region ap-southeast-1 \
#     --create-bucket-configuration LocationConstraint=ap-southeast-1
#   aws s3api put-bucket-versioning --bucket scroogebank-crm-prod-tfstate \
#     --versioning-configuration Status=Enabled
#   aws dynamodb create-table --table-name scroogebank-crm-prod-tflock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region ap-southeast-1
#--------------------------------------------------

bucket         = "scroogebank-crm-prod-tfstate"
key            = "scroogebank-crm/prod/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "scroogebank-crm-prod-tflock"
encrypt        = true
