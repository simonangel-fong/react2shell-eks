# outputs.tf

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

output "rds_secret_arn" {
  description = "Crown-jewel secret ARN (phase 10 target)."
  value       = aws_secretsmanager_secret.rds.arn
}

output "pod_irsa_role_arn" {
  description = "IRSA role ARN assumed by the react pod."
  value       = aws_iam_role.pod.arn
}
