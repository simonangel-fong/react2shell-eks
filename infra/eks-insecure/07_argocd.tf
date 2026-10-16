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

# Install App-of-apps root as a tiny local Helm chart.
resource "helm_release" "root_app" {
  name      = "root-app"
  namespace = local.argocd_namespace
  chart     = "${path.module}/charts/root-app"

  set = [
    {
      name  = "namespace"
      value = local.argocd_namespace
    },
    {
      name  = "repoURL"
      value = local.argocd_repo_url
    },
    {
      name  = "targetRevision"
      value = local.argocd_target_rev
    },
    {
      name  = "path"
      value = "${local.argocd_root_app_path}/apps"
    },
  ]

  depends_on = [helm_release.argocd]
}
