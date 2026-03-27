#--------------------------------------------------------------
# ALB Module - Route53 DNS Record
# Creates an A record (alias) pointing to the ALB.
# Uses the EXISTING school-provided Route53 hosted zone.
# IMPORTANT: This does NOT create/delete the hosted zone itself.
#--------------------------------------------------------------

resource "aws_route53_record" "alb" {
  count = var.manage_route53_record && var.use_custom_domain && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.alb_subdomain
  type    = "A"

  alias {
    name                   = aws_lb.crm.dns_name
    zone_id                = aws_lb.crm.zone_id
    evaluate_target_health = true
  }

  lifecycle {
    # Prevent accidental deletion of DNS record
    prevent_destroy = true
    # Ignore changes to zone_id to prevent replacement if zone is recreated
    ignore_changes = [zone_id]
  }
}
