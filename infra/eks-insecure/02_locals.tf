# locals.tf

locals {
  # ##############################
  # metadata
  # ##############################
  project     = "react2shell-eks"
  env         = "insecure"
  aws_region  = "ca-central-1"
  common_name = "${local.project}-${local.env}"

  default_tags = {
    Project     = "${local.project}"
    Environment = "${local.env}"
    ManagedBy   = "terraform"
  }

  # ##############################
  # vpc
  # ##############################
  vpc_cidr = "10.0.0.0/16"
  vpc_az   = ["ca-central-1a", "ca-central-1b"]

  # ##############################
  # eks
  # ##############################
  eks_name         = "${local.project}-${local.env}"
  eks_version      = "1.36"
  eks_node_type    = "t3.medium"
  eks_node_min     = 2
  eks_node_max     = 5
  eks_node_desired = 3
  # control plane logging
  eks_log_types          = ["audit", "authenticator"]
  eks_log_retention_days = 7

  # ##############################
  # Argocd
  # ##############################
  argocd_namespace     = "argocd"
  argocd_chart_version = "10.10.0"

  # ##############################
  # irsa (MISCONFIG to enable exploit)
  # ##############################
  irsa_namespace = "insecure-frontend"
  irsa_sa        = "react2shell"
}

