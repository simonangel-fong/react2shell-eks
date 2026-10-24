# acm.tf
# The wildcard certificate already exists; it is looked up rather than created.
# CloudFront only accepts certificates from us-east-1, whatever region the rest
# of the stack runs in.

data "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain      = local.site_cert_domain
  statuses    = ["ISSUED"]
  most_recent = true
}
