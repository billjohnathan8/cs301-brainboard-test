#--------------------------------------------------------------
# ACM Module - Provider Configuration
# Requires both us-east-1 and ap-southeast-1 provider aliases
# for creating certificates in both regions.
#--------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1, aws.ap_southeast_1]
    }
  }
}
