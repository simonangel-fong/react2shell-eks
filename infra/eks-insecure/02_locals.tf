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
<<<<<<< HEAD
  # Upstream Gateway API, standard channel. LBC v3.x requires v1.6.x.
  gateway_api_version = "v1.6.3"
  # AWS LBC release tag; sources the gateway.k8s.aws CRDs.
  lbc_crd_version = "v3.6.0"

  # ##############################
  # aws load balancer controller
  # ##############################
  albc_namespace       = "kube-system"
  albc_service_account = "aws-load-balancer-controller"
  albc_chart_version   = "3.6.0"

  # ##############################
  # dns / tls exposure
  # ##############################
  # Public hostname, proxied through Cloudflare.
  app_host = "react2shell-insecure.arguswatcher.net"
  # Cloudflare zone that hosts app_host.
  dns_zone = "arguswatcher.net"
  # Wildcard cert covering app_host, in the ALB's region.
  # CloudFlare Origin CA cert: edge-trusted only, proxied mode required.
  acm_domain = "*.arguswatcher.net"

  # ##############################
  # irsa (MISCONFIG to enable exploit
  # ##############################
  irsa_namespace = "insecure-frontend"
=======
  irsa_namespace = "react"
>>>>>>> secure
  irsa_sa        = "react2shell"
}

