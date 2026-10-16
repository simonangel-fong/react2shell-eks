# albc.tf

# ##############################
# AWS Load Balancer Controller
# Step 3 of the DNS exposure chain:
#   deploy -> svc -> Gateway -> ALB -> Cloudflare
#
# Installed here rather than via ArgoCD because it is cluster
# plumbing with an IAM dependency (same tier as argocd itself in
# 07_argocd.tf). The Gateway/HTTPRoute that *use* it live in git,
# reconciled by ArgoCD.
#
# serviceAccount.create = true: the chart creates the SA whose name
# the Pod Identity association in 11_albc_iam.tf already targets.
# No role-arn annotation is needed (that is the IRSA pattern).
#
# Gateway API: ALBGatewayAPI / NLBGatewayAPI feature gates default to
# true in v3.6.0, so no featureGates override is required. The chart
# bundles the gateway.k8s.aws CRDs in crds/, matching 10_gateway_api.tf.
# ##############################

resource "helm_release" "albc" {
  name       = "aws-load-balancer-controller"
  namespace  = local.albc_namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = local.albc_chart_version

  # Wait for the webhook to be serving before anything applies a
  # Gateway, or admission calls fail.
  wait    = true
  timeout = 600

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = local.albc_service_account
    },
    # Skip IMDS lookups; both are known from terraform state.
    {
      name  = "region"
      value = local.aws_region
    },
    {
      name  = "vpcId"
      value = module.vpc.vpc_id
    },
  ]

  depends_on = [
    module.albc_pod_identity,
    null_resource.gateway_api_crds,
  ]
}
