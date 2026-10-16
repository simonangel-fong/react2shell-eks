# albc_iam.tf

# ##############################
# AWS Load Balancer Controller: pod identity
# Step 2 of the DNS exposure chain:
#   deploy -> svc -> Gateway -> ALB -> Cloudflare
#
# Pod Identity instead of IRSA:
#   - no OIDC `sub` string matching in a trust policy
#   - credentials are delivered by the node-local agent, scoped to
#     the (cluster, namespace, service account) triple
#   - eks-pod-identity-agent is already enabled in 06_eks.tf
#
# The module ships the upstream LBC IAM policy, so the ~16-statement
# policy document is not vendored here and tracks the module version.
#
# NOTE: this is the controller's own role, NOT the deliberately
# over-permissioned pod role in 09_irsa.tf. Keep the two distinct:
# the breach narrative depends on the broad role belonging only to
# the react2shell SA.
# ##############################

module "albc_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.9"

  name = "${local.common_name}-albc"
  # Exact name, matching the IRSA role in 09_irsa.tf
  # (module defaults to a random-suffixed name_prefix).
  use_name_prefix = false

  # Upstream aws-load-balancer-controller IAM policy.
  attach_aws_lb_controller_policy = true

  associations = {
    albc = {
      cluster_name    = module.eks.cluster_name
      namespace       = local.albc_namespace
      service_account = local.albc_service_account
    }
  }

  tags = local.default_tags

  depends_on = [module.eks]
}
