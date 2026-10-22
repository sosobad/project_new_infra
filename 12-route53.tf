
# # ============================================================
# # Route 53
# # Domain: soladmins.com
# # ============================================================

# data "aws_route53_zone" "soladmins" {
#   name         = "soladmins.com"
#   private_zone = false
# }

# # ============================================================
# # API
# # api.soladmins.com -> Ingress Load Balancer
# # ============================================================

# resource "aws_route53_record" "api" {
#   zone_id = data.aws_route53_zone.soladmins.zone_id
#   name    = "api.soladmins.com"
#   type    = "CNAME"
#   ttl     = 300

#   records = [
#     local.public_alb_dns
#   ]
# }

# # ============================================================
# # Frontend
# # www.soladmins.com -> Ingress Load Balancer
# # ============================================================

# resource "aws_route53_record" "www" {
#   zone_id = data.aws_route53_zone.soladmins.zone_id
#   name    = "www.soladmins.com"
#   type    = "CNAME"
#   ttl     = 300

#   records = [
#     local.public_alb_dns
#   ]
# }
