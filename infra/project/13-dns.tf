# dns.tf
# DNS-only (grey cloud): CloudFront terminates TLS with the ACM certificate.
# Proxying through Cloudflare would add a second cache to purge on every deploy.

resource "cloudflare_record" "site" {
  zone_id = var.cloudflare_zone_id
  name    = split(".", local.site_domain)[0]
  type    = "CNAME"
  content = aws_cloudfront_distribution.site.domain_name
  proxied = false
  ttl     = 1 # automatic
  comment = "Managed by Terraform - ${local.project_name}"
}
