# reat2shell: Secure EKS

[Back](../README.md)

- [reat2shell: Secure EKS](#reat2shell-secure-eks)
  - [Goal](#goal)
  - [Scope: Cloud Layer Only](#scope-cloud-layer-only)
  - [Infra Design](#infra-design)
  - [Harden Steps](#harden-steps)
  - [Proof](#proof)
  - [Sidebar: Scope the Role (if the app truly needs AWS)](#sidebar-scope-the-role-if-the-app-truly-needs-aws)
  - [Shift Left: Scan Terraform](#shift-left-scan-terraform)
  - [Infra provision](#infra-provision)
    - [EKS](#eks)
    - [ArgoCD](#argocd)

---

## Goal

1. Create EKS cluster with secure cloud configurations
   - `eks-secure`
2. Keep the cloud crown jewel — the **RDS secret in Secrets Manager** — but make
   it **unreachable** from the cluster.
3. Deploy the **same insecure app** via `GitOps`.

- Headline fix: **remove the pod's unneeded AWS identity** (IRSA).
- Target: the broad `*/*` role on SA `insecure-frontend:react2shell`.

---

## Scope: Cloud Layer Only

The lab hardens in four layers — **code, container, cluster, cloud**. This phase
isolates the **cloud** layer: it assumes code, container, and cluster are **still
compromised** and fixes AWS only.

| Layer     | State in this phase         |
| --------- | --------------------------- |
| Code      | insecure (RCE still works)  |
| Container | insecure (root, no seccomp) |
| Cluster   | insecure (broad RBAC)       |
| Cloud     | **hardened** (this phase)   |

- Environment = **`eks-secure` cluster + the insecure app** (`insecure` branch,
  `insecure-frontend`).
- The pod can still be popped. The point: the breach is **contained at the cloud
  boundary** — RCE yields nothing in AWS.

**Least privilege, applied honestly.** The `react2shell` app makes **no AWS API
calls** (deps: `next`, `react`, `react-dom` only — no AWS SDK). The pod's IRSA
role only ever served the attacker's uploaded `steal_secret.js`. A workload that
calls no AWS API needs **no AWS identity**. So the correct fix is not to _narrow_
the role — it is to **remove it**.

> The secret stays in Secrets Manager. Nothing in the cluster is granted a way to
> reach it. If a workload _did_ legitimately need it, it would be scoped and
> mounted — see the [sidebar](#sidebar-scope-the-role-if-the-app-truly-needs-aws).

---

## Infra Design

Terraform in a single stack, mirroring phase 9 — **minus the IRSA misconfig**.

```txt
infra/
  eks-secure/       # secure cluster + crown jewel, no pod IAM identity — remote state
```

- **Remote state**:
  - uses an **existing** S3 bucket (versioned, encrypted).

- Infrastructure layers built with AWS modules:

| Layers | Features                                                       |
| ------ | -------------------------------------------------------------- |
| VPC    | 2 AZs; subnets: public+private                                 |
| EKS    | node group, OIDC enabled                                       |
| Secret | Secrets Manager holding a fake RDS credential; the crown jewel |
| irsa   | **removed** — no role, no trust policy for the pod             |

**Build order:** `eks-secure/`: vpc → cluster → secret

**Milestone check:** `kubectl get nodes` ready; from inside the pod,
`cat $AWS_WEB_IDENTITY_TOKEN_FILE` → **no such file** (no identity projected).

---

## Harden Steps

Cut the one real cloud misconfig: the pod's broad AWS identity.

| #   | Step                | What                                                               | Result                                 |
| --- | ------------------- | ------------------------------------------------------------------ | -------------------------------------- |
| 1   | Drop the IAM role   | Delete the `aws_iam_role.pod` + `*/*` inline policy (no `irsa.tf`) | No role for the pod to assume          |
| 2   | Drop the SA binding | Remove `eks.amazonaws.com/role-arn` from the frontend SA (git)     | No web-identity token projected        |
| 3   | apply + re-breach   | `terraform apply`, re-run Phase 9 attack commands                  | Breach contained at the cloud boundary |

> **Note:** phase 9's IRSA _trust policy_ was already correct (`sub` pinned to the
> one SA, `aud = sts.amazonaws.com`). The only cloud misconfig was the broad
> `Action:* Resource:*` inline policy. Removing the whole role retires both.

---

## Proof

Same pod, same insecure app, same attacker `steal_secret.js` — only the **cloud**
config changed. No AWS identity reaches the pod.

| Action                             | Before (phase 9) | After (phase 10)           |
| ---------------------------------- | ---------------- | -------------------------- |
| `env \| grep AWS_ROLE_ARN`         | role ARN present | **empty** (no annotation)  |
| `cat $AWS_WEB_IDENTITY_TOKEN_FILE` | JWT token        | **No such file**           |
| `node /tmp/s.js` (get RDS)         | 🪙 secret        | **no credentials** — fails |
| `node /tmp/s.js --list`            | lists secrets    | **no credentials** — fails |

- RCE still lands (app unchanged), but there is **nothing to assume** — the attack
  chain dead-ends before STS.
- Cloud mirror of the cluster-level `403 secrets is forbidden`: the crown jewel is
  present but unreachable from the cluster.

**Milestone:** secure at cloud level.

---

## Sidebar: Scope the Role (if the app truly needs AWS)

Removing IRSA is correct **because this app calls no AWS API**. When a workload
_does_ legitimately need a secret, least privilege means **scope, not remove**:

| #   | Step               | What                                            | Result                            |
| --- | ------------------ | ----------------------------------------------- | --------------------------------- |
| 1   | Scope the policy   | `Action:* Resource:*` → `GetSecretValue` only   | Broad reach gone                  |
| 2   | Reference the ARN  | `Resource = aws_secretsmanager_secret.rds.arn`  | Stays correct if secret recreated |
| 3   | Keep trust tight   | `sub` = the one SA, `aud = sts.amazonaws.com`   | No other pod can assume the role  |
| 4   | Mount, don't fetch | Inject via Secrets Store CSI / External Secrets | App reads a file, not the AWS API |

- Then `GetSecretValue` on that ARN succeeds (app works); `--list` and every other
  secret/service → `AccessDeniedException`.
- This phase does **not** use this path — the app needs no AWS, so it gets none.

---

## Shift Left: Scan Terraform

Catch IAM misconfig at the PR, before apply — extends the Phase 8 pattern
(`trivy config` on manifests) to the terraform. Reuses the same action, so one
tool covers image + manifest + IaC.

| #   | Step              | What                                                       | Result                          |
| --- | ----------------- | ---------------------------------------------------------- | ------------------------------- |
| 1   | New workflow      | `scan-terraform.yml`, triggered on `infra/**` changes      | TF scanned on every PR          |
| 2   | Trivy config scan | `trivy config infra/eks-secure`, `severity: HIGH,CRITICAL` | Flags wildcard IAM, open config |
| 3   | Gate the PR       | Fail the job on findings                                   | Insecure terraform rejected     |
| 4   | Accept exceptions | `infra/eks-secure/.trivyignore` for reviewed cases         | Intentional configs documented  |

- Mirrors Phase 8: _insecure push gets rejected_ — now for IaC.
- Same `aquasecurity/trivy-action`, same severity gate already used for images
  and manifests.

---

## Infra provision

### EKS

```sh
# init
terraform -chdir=infra/eks-secure init -backend-config=backend.hcl
terraform -chdir=infra/eks-secure init -backend-config=backend.hcl -reconfigure
terraform -chdir=infra/eks-secure init -backend-config=backend.hcl -upgrade

terraform -chdir=infra/eks-secure fmt && terraform -chdir=infra/eks-secure validate
terraform -chdir=infra/eks-secure plan

terraform -chdir=infra/eks-secure apply -auto-approve
terraform -chdir=infra/eks-secure refresh
terraform -chdir=infra/eks-secure output

# clean up
terraform -chdir=infra/eks-secure destroy -auto-approve
```

---

### ArgoCD

```sh
# kubeconfig
aws eks update-kubeconfig --region ca-central-1 --name react2shell-eks-secure
kubectl get nodes

# argocd synced the app-of-apps
kubectl get applications -n argocd

# port-forward the argocd
# get pwd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo
# port forward
kubectl port-forward service/argocd-server -n argocd 8443:443

kubectl apply -f argocd/insecure-root-app-cloud.yaml

```

---
