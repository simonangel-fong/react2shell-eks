# argocd.tf

# install argocd via helm
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = local.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = local.argocd_chart_version

  # Wait for CRDs + controllers to be ready before the root app is applied.
  wait = true

  depends_on = [module.eks]
}
