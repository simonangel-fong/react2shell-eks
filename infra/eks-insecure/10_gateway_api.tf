# gateway_api.tf

# ##############################
# Gateway API CRDs
# Step 1 of the DNS exposure chain:
#   deploy -> svc -> Gateway -> ALB -> Cloudflare
#
# Two separate CRD sets are required:
#   1. Upstream Gateway API (standard channel) - the portable API
#   2. AWS LBC gateway CRDs                    - ALB-specific config
#
# Applied with `kubectl apply --server-side` because the upstream
# standard-install.yaml is ~1.1MB, over the client-side apply
# annotation limit (262144 bytes).
#
# interpreter is set explicitly: on Windows local-exec defaults to
# cmd.exe, which silently exits 0 on a multi-line command.
# ##############################

# Upstream Gateway API, standard channel.
# Installs 10 CRDs + the safe-upgrades ValidatingAdmissionPolicy, which
# blocks mixing standard and experimental CRDs of the same kind.
resource "null_resource" "gateway_api_crds" {
  triggers = {
    version = local.gateway_api_version
    cluster = module.eks.cluster_name
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-Command"]
    command     = "kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.gateway_api_version}/standard-install.yaml; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"
  }

  depends_on = [module.eks]
}

# AWS LBC gateway CRDs: TargetGroupConfiguration,
# LoadBalancerConfiguration, ListenerRuleConfiguration.
# Pinned to the chart's matching tag rather than main.
resource "null_resource" "lbc_gateway_crds" {
  triggers = {
    version = local.lbc_crd_version
    cluster = module.eks.cluster_name
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-Command"]
    command     = "kubectl apply --server-side=true -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${local.lbc_crd_version}/config/crd/gateway/gateway-crds.yaml; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"
  }

  depends_on = [null_resource.gateway_api_crds]
}
