#--------------------------------------------------------------
# ACM Module
# Creates and validates SSL/TLS certificates for CloudFront and ALB
# using DNS validation via Route53.
#--------------------------------------------------------------

#--------------------------------------------------------------
# CloudFront Certificate (US East 1)
# CloudFront requires certificates in the us-east-1 region
# regardless of where your application is deployed.
#--------------------------------------------------------------
resource "aws_acm_certificate" "us_cert" {
  provider          = aws.us_east_1
  domain_name       = "*.${var.app_domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-cloudfront-certificate"
  }
}

#--------------------------------------------------------------
# Application Certificate (AP Southeast 1)
# Certificate for resources in the primary region.
# Used for ALB and other regional services.
#--------------------------------------------------------------
resource "aws_acm_certificate" "ap_cert" {
  provider                  = aws.ap_southeast_1
  domain_name               = var.app_domain_name
  subject_alternative_names = ["*.${var.app_domain_name}", "${var.alb_origin_subdomain}.${var.app_domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-ap-certificate"
  }
}

#--------------------------------------------------------------
# Certificate Validation
# DNS validation creates Route53 records to prove domain ownership.
# Certificates must be validated before they can be used.
#--------------------------------------------------------------
locals {
  us_validation_record_names = [
    for dvo in aws_acm_certificate.us_cert.domain_validation_options : dvo.resource_record_name
  ]

  ap_validation_record_names = [
    for dvo in aws_acm_certificate.ap_cert.domain_validation_options : dvo.resource_record_name
  ]
}

resource "aws_acm_certificate_validation" "us_cert_validation" {
  count = var.wait_for_validation ? 1 : 0

  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.us_cert.arn
  validation_record_fqdns = local.us_validation_record_names

  depends_on = [aws_route53_record.us_cert_validation]
}

resource "aws_acm_certificate_validation" "ap_cert_validation" {
  count = var.wait_for_validation ? 1 : 0

  provider                = aws.ap_southeast_1
  certificate_arn         = aws_acm_certificate.ap_cert.arn
  validation_record_fqdns = local.ap_validation_record_names

  depends_on = [aws_route53_record.ap_cert_validation]
}
