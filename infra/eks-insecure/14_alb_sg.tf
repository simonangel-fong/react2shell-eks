# alb_sg.tf

# ##############################
# ALB security group: Cloudflare-only ingress
# Step 5 of the DNS exposure chain:
#   deploy -> svc -> Gateway -> ALB -> Cloudflare
#
# WHY THIS IS REQUIRED, not optional:
# The cert in 13_acm.tf is a CloudFlare Origin CA cert, trusted only
# by the Cloudflare edge. Proxied mode puts Cloudflare in front, but
# an ALB left open to 0.0.0.0/0 is still reachable by its raw
# *.elb.amazonaws.com name -- which bypasses Cloudflare entirely
# (no WAF, no rate limiting, no access logs at the edge).
#
# Locking ingress to Cloudflare's published ranges closes that path.
# The Gateway references this SG via LoadBalancerConfiguration.
#
# Ranges are fetched at plan time, not hardcoded: Cloudflare adds
# ranges periodically. A terraform apply re-reads them.
# ##############################

data "http" "cloudflare_ips_v4" {
  url = "https://www.cloudflare.com/ips-v4"
}

data "http" "cloudflare_ips_v6" {
  url = "https://www.cloudflare.com/ips-v6"
}

locals {
  cloudflare_cidrs_v4 = compact(split("\n", trimspace(data.http.cloudflare_ips_v4.response_body)))
  cloudflare_cidrs_v6 = compact(split("\n", trimspace(data.http.cloudflare_ips_v6.response_body)))
}

resource "aws_security_group" "alb" {
  name        = "${local.common_name}-alb"
  description = "ALB ingress restricted to Cloudflare edge ranges"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.default_tags, {
    Name = "${local.common_name}-alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS from Cloudflare only. Origin TLS uses the Origin CA cert.
resource "aws_vpc_security_group_ingress_rule" "alb_https_v4" {
  for_each = toset(local.cloudflare_cidrs_v4)

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from Cloudflare ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_v6" {
  for_each = toset(local.cloudflare_cidrs_v6)

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from Cloudflare ${each.value}"
  cidr_ipv6         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Egress to the pods. Targets are pod IPs inside the VPC (ip mode).
resource "aws_vpc_security_group_egress_rule" "alb_to_vpc" {
  security_group_id = aws_security_group.alb.id
  description       = "To pod targets in the VPC"
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "-1"
}
