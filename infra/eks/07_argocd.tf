# argocd.tf
# 1. helm_release installs Argo CD (CRDs + controllers).
# 2. kubectl_manifest seeds the app-of-apps root AFTER the CRDs exist.
#    alekc/kubectl applies raw YAML with no plan-time schema lookup, so it
#    works on a freshly-created cluster (unlike kubernetes_manifest).

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

# App-of-apps root. CRD is installed by the release above.
resource "kubectl_manifest" "root_app" {
  yaml_body = yamlencode({
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
  })

  depends_on = [helm_release.argocd]
}
