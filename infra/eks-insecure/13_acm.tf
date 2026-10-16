# acm.tf

# ##############################
# ACM certificate (lookup, not creation)
# Step 4 of the DNS exposure chain:
#   deploy -> svc -> Gateway -> ALB -> Cloudflare
#
# Reuses the pre-existing wildcard cert in the ALB's region.
# This is a CloudFlare Origin CA certificate: it is trusted by the
# Cloudflare edge, NOT by public browsers. That is correct here
# because the record is proxied (orange cloud):
#
#   browser --TLS(CF edge cert)--> Cloudflare --TLS(this cert)--> ALB
#
# Consequence: the ALB must never be reached directly. See the
# security-group lock in 14_alb_sg.tf.
#
# Looked up rather than managed: the cert is account-level shared
# infrastructure, predates this stack, and is IMPORTED (so terraform
# could not recreate it without the private key).
# ##############################

data "aws_acm_certificate" "wildcard" {
  domain      = local.acm_domain
  statuses    = ["ISSUED"]
  most_recent = true
}
