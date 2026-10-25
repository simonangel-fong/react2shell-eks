# locals.tf

locals {

  # ##############################
  # metadata
  # ##############################
  project_name = "react2shell-eks"
  prefix_name  = "${local.project_name}-project"
  default_tags = {
    Project   = local.project_name
    Env       = "project"
    ManagedBy = "Terraform"
  }

  # ##############################
  # aws
  # ##############################
  aws_region = "ca-central-1"


  # ##############################
  # website
  # ##############################
  site_domain      = "react2shell-eks.arguswatcher.net"
  site_cert_domain = "*.arguswatcher.net"
  site_origin_id   = "s3-${local.prefix_name}-site"


  # ##############################
  # GitHub
  # ##############################
  github_owner      = "simonangel-fong"
  github_repo       = "react2shell-eks"
  github_owner_id   = "64545430"   # gh api user --jq .id
  github_repo_id    = "1406439181" # gh api repos/simonangel-fong/react2shell-eks --jq '.id'
  github_sub_prefix = "repo:${local.github_owner}@${local.github_owner_id}/${local.github_repo}@${local.github_repo_id}"
}
