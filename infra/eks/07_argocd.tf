# argocd.tf
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = local.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = local.argocd_chart_version

  # Wait for the chart's resources.
  wait = true

  # Seed the app-of-apps root.
  values = [
    yamlencode({
      extraObjects = [
        {
          apiVersion = "argoproj.io/v1alpha1"
          kind       = "Application"
          metadata = {
            name      = "01-root-app"
            namespace = local.argocd_namespace
            finalizers = [
              "argocd.argoproj.io/resources-finalizer"
            ]
          }
          spec = {
            project = "default"
            source = {
              repoURL        = local.argocd_repo_url
              targetRevision = local.argocd_target_rev
              path           = "${local.argocd_root_app_path}/apps"
            }
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = local.argocd_namespace
            }
            syncPolicy = {
              automated = {
                prune    = true
                selfHeal = true
              }
              syncOptions = [
                "CreateNamespace=true"
              ]
            }
          }
        }
      ]
    })
  ]

  depends_on = [module.eks]
}
