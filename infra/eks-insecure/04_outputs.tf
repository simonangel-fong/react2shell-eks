# outputs.tf

# ##############################
# VPC
# ##############################
output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (load balancers / NAT)."
  value       = module.vpc.public_subnets
}

# ##############################
# EKS
# ##############################
output "cluster_name" {
  description = "EKS cluster name (for aws eks update-kubeconfig)."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN (IRSA role trust)."
  value       = module.eks.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Command to update local kubeconfig."
  value       = "aws eks update-kubeconfig --region ${local.aws_region} --name ${module.eks.cluster_name}"
}

# Monitoring
output "cluster_log_group" {
  description = "CloudWatch log group holding the control plane (audit) logs."
  value       = module.eks.cloudwatch_log_group_name
}

output "cloudtrail_name" {
  description = "CloudTrail trail recording the AWS API plane."
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_bucket" {
  description = "S3 bucket holding the CloudTrail logs."
  value       = aws_s3_bucket.trail.bucket
}

output "cloudtrail_log_group" {
  description = "CloudWatch log group for CloudTrail (Logs Insights queries)."
  value       = aws_cloudwatch_log_group.trail.name
}

output "rds_secret_arn" {
  description = "Crown-jewel secret ARN (phase 10 target)."
  value       = aws_secretsmanager_secret.rds.arn
}

output "pod_irsa_role_arn" {
  description = "IRSA role ARN assumed by the insecure-frontend pod."
  value       = aws_iam_role.pod.arn
}
