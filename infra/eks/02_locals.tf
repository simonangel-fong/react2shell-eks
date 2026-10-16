# locals.tf

locals {
  # ##############################
  # metadata
  # ##############################
  project     = "react2shell-eks"
  env         = "dev"
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
  eks_name       = "${local.project}-${local.env}"
  eks_version    = "1.34"
  eks_node_type  = "t3.medium"
  eks_node_min   = 2
  eks_node_max   = 3
  eks_node_desed = 2

  # ##############################
  # argocd
  # ##############################
  argocd_namespace     = "argocd"
  argocd_chart_version = "10.10.0"
  argocd_repo_url      = "https://github.com/simonangel-fong/react2shell-eks.git"
  argocd_root_app_path = "argocd"
  argocd_target_rev    = "master"

  # ##############################
  # irsa (MISCONFIG target — the pod exploited in phase 10)
  # ##############################
  irsa_namespace = "insecure-frontend"
  irsa_sa        = "react2shell"
}

