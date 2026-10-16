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

output "rds_secret_arn" {
  description = "Crown-jewel secret ARN (phase 10 target)."
  value       = aws_secretsmanager_secret.rds.arn
}

output "pod_irsa_role_arn" {
  description = "IRSA role ARN assumed by the insecure-frontend pod."
  value       = aws_iam_role.pod.arn
}

# ##############################
# AWS Load Balancer Controller
# ##############################
output "albc_role_arn" {
  description = "Pod Identity role ARN used by the AWS Load Balancer Controller."
  value       = module.albc_pod_identity.iam_role_arn
}

# ##############################
# DNS / TLS exposure
# ##############################
output "app_host" {
  description = "Public hostname (Cloudflare-proxied) for the app."
  value       = local.app_host
}

output "acm_certificate_arn" {
  description = "ACM cert ARN for the Gateway HTTPS listener (Cloudflare Origin CA)."
  value       = data.aws_acm_certificate.wildcard.arn
}

output "alb_security_group_id" {
  description = "ALB security group (Cloudflare-only ingress) for LoadBalancerConfiguration."
  value       = aws_security_group.alb.id
}
