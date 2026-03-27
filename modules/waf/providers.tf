#--------------------------------------------------------------
# WAF Module - Provider Configuration
# Requires us-east-1 alias for CloudFront-scoped WAF resources.
#--------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
