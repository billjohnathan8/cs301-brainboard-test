#--------------------------------------------------------------
# SES Module - Amazon Simple Email Service
# This module manages SES for sending transactional emails
# Supports both email identity verification and domain-based setup
# with DKIM, SPF, and custom MAIL FROM configuration
#--------------------------------------------------------------
locals {
  notification_identity = var.domain != "" ? var.domain : var.sender_email
}

# SES Email Identity Verification (Fallback Method)
# Used when a full domain setup is not available
# Requires email verification via AWS console or confirmation link
resource "aws_ses_email_identity" "verification" {
  count = var.enable_ses && var.sender_email != "" && var.domain == "" ? 1 : 0

  email = var.sender_email
}

# SES Domain Identity
# Verifies entire domain for sending emails from any address @domain
# Preferred over individual email verification for production use
resource "aws_ses_domain_identity" "this" {
  count = var.domain != "" ? 1 : 0

  domain = var.domain
}

# DKIM (DomainKeys Identified Mail) Configuration
# Cryptographic authentication to prove email authenticity
# Improves email deliverability and reduces spam classification
# Generates 3 CNAME tokens that must be added to DNS
resource "aws_ses_domain_dkim" "this" {
  count = var.domain != "" ? 1 : 0

  domain = aws_ses_domain_identity.this[0].domain
}

# Custom MAIL FROM Domain
# Sets up a custom MAIL FROM domain instead of amazonses.com
# Improves SPF alignment and reduces Gmail warning messages
# Requires MX and TXT (SPF) records in DNS:
# - MX: {mail_from_domain} -> 10 feedback-smtp.{region}.amazonses.com
# - TXT: {mail_from_domain} -> v=spf1 include:amazonses.com ~all
resource "aws_ses_domain_mail_from" "this" {
  count = var.domain != "" ? 1 : 0

  domain           = aws_ses_domain_identity.this[0].domain
  mail_from_domain = "${var.mail_from_subdomain}.${var.domain}"
}

resource "aws_ses_identity_notification_topic" "events" {
  for_each = (
    var.enable_ses &&
    var.notification_topic_arn != "" &&
    local.notification_identity != ""
  ) ? toset(["Bounce", "Complaint", "Delivery"]) : toset([])

  identity          = local.notification_identity
  notification_type = each.value
  topic_arn         = var.notification_topic_arn
}
