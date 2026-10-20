# irsa.tf

# ##############################
# MISCONFIG: deliberate vulnerability
# A broad IAM policy (Action:* Resource:*) attached to the pod's IRSA role.
# RCE inherits it → reads the crown-jewel secret.
# ##############################

# Trust policy: the insecure-frontend SA assumes this role via the cluster OIDC.
data "aws_iam_policy_document" "irsa_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:${local.irsa_namespace}:${local.irsa_sa}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ##############################
# IAM role:
# SA `eks.amazonaws.com/role-arn` annotation lives in the git manifest (argocd/insecure-frontend/rbac.yaml)
# ##############################
resource "aws_iam_role" "pod" {
  name               = "${local.common_name}-pod-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
}

# MISCONFIG: full admin.
data "aws_iam_policy_document" "pod_admin" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "pod_admin" {
  name   = "admin"
  role   = aws_iam_role.pod.id
  policy = data.aws_iam_policy_document.pod_admin.json
}
