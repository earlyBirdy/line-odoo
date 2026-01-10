resource "aws_route53_record" "alias" {
  for_each = { for r in var.records : r.name => r }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = "A"

  alias {
    name                   = each.value.alb_dns_name
    zone_id                = each.value.alb_zone_id
    evaluate_target_health = true
  }
}
