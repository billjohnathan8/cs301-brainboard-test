#--------------------------------------------------------------
# SES Module - Outputs
#--------------------------------------------------------------

output "domain_identity_arn" {
  description = "SES domain identity ARN."
  value       = var.domain != "" ? aws_ses_domain_identity.this[0].arn : null
}

output "domain_verification_token" {
  description = "TXT record value for SES domain verification. Create DNS record: _amazonses.{domain} TXT {token}"
  value       = var.domain != "" ? aws_ses_domain_identity.this[0].verification_token : null
}

output "dkim_tokens" {
  description = "DKIM CNAME tokens. Create 3 DNS records: {token}._domainkey.{domain} CNAME {token}.dkim.amazonses.com"
  value       = var.domain != "" ? aws_ses_domain_dkim.this[0].dkim_tokens : []
}

output "mail_from_domain" {
  description = "Custom MAIL FROM domain. Requires DNS records: MX: {mail_from_domain} -> 10 feedback-smtp.{region}.amazonses.com AND TXT: {mail_from_domain} -> v=spf1 include:amazonses.com ~all"
  value       = var.domain != "" ? "${var.mail_from_subdomain}.${var.domain}" : null
}

output "email_identity_arn" {
  description = "SES email identity ARN (when using email verification instead of domain)."
  value       = var.enable_ses && var.sender_email != "" && var.domain == "" ? aws_ses_email_identity.verification[0].arn : null
}
