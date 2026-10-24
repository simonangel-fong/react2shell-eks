# output.tf

output "site_url" {
  description = "Public URL of the project website"
  value       = "https://${local.site_domain}"
}

output "site_bucket" {
  description = "Origin bucket holding the website content"
  value       = aws_s3_bucket.site.id
}

output "site_cloudfront_domain" {
  description = "CloudFront domain the Cloudflare CNAME points at"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "site_cloudfront_distribution_id" {
  description = "Distribution id, for cache invalidation after a content update"
  value       = aws_cloudfront_distribution.site.id
}

output "github_oidc_role_arn" {
  description = "Set as the AWS_ROLE_ARN repository variable in GitHub"
  value       = aws_iam_role.github_deploy.arn
}
