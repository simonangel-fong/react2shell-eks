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
  eks_version    = "1.33"
  eks_node_type  = "t3.medium"
  eks_node_min   = 2
  eks_node_max   = 3
  eks_node_desed = 2
}

