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
