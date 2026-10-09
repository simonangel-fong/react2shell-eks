# reat2shell: EKS

[Back](../README.md)

- [reat2shell: EKS](#reat2shell-eks)
  - [Overview](#overview)
  - [Identity Shift: K8s to AWS](#identity-shift-k8s-to-aws)
  - [Infra Design](#infra-design)
  - [Key Misconfigs](#key-misconfigs)
  - [Keep Secure (do not regress)](#keep-secure-do-not-regress)
  - [Shortened Attack Chain](#shortened-attack-chain)
  - [EKS](#eks)

---

## Overview

Move the lab to EKS. The in-cluster hardening (RBAC, PSS, NP, no auto-mounted SA
token) still applies. What is **new** is the cloud identity plane: a compromised
pod can become an **AWS principal** and read the cloud crown jewel — the **RDS
secret in Secrets Manager**.

Phase plan:

- **Phase 9 (this doc)** — build EKS with deliberate misconfigs.
- **Phase 10** — breach: RCE → cloud secret.
- **Phase 11** — harden cloud: fix the misconfigs, re-run the breach, it fails.

---

## Identity Shift: K8s to AWS

- On kind, the deepest token a pod could steal was a **K8s** SA token.
- On EKS, the pod carries an **IRSA** identity (projected AWS token +
  `AWS_ROLE_ARN`). The AWS SDK assumes the role transparently.
- RCE still has shell in the pod, so these AWS env vars/token are reachable
  **even though the K8s SA token is gone**. The thing that matters now is the
  **IAM policy**, not RBAC.

> Cloud equivalent of the cluster story: a too-broad **RoleBinding** becomes a
> too-broad **IAM policy**.

---

## Infra Design

Terraform in a single stack (per `AGENTS.md` layout):

```txt
infra/
  eks/       # cluster + crown jewel + misconfig — remote state
```

- **Remote state** — uses an **existing** S3 bucket (versioned, encrypted).
  **Native S3 locking** via `use_lockfile = true` — no DynamoDB table
  (deprecated since TF 1.11; needs TF ≥ 1.10). Use a project-specific `key`
  prefix to avoid collisions.
- **eks/** — built with `terraform-aws-modules`:

| Area               | What                                                   | Posture               |
| ------------------ | ------------------------------------------------------ | --------------------- |
| vpc                | `terraform-aws-modules/vpc` — 2 AZs, public+private    | secure: nodes private |
| eks                | `terraform-aws-modules/eks` — node group, OIDC enabled | secure: IMDSv2, hop=1 |
| secret             | Secrets Manager holding a fake RDS credential          | the crown jewel       |
| irsa _(misconfig)_ | IRSA role for SA `secure-frontend:react2shell`         | **admin `*/*`**       |
| access             | EKS access entry for the admin identity                | secure                |

- Crown jewel: **Secrets Manager only** (no real RDS yet — same `get-secret-value`
  chain, cheaper). RDS can be added later.
- The misconfig is isolated to the **irsa** file, so the Phase 11 fix is a
  one-file diff.

**Build order:** `eks/`: vpc → cluster → secret → irsa → access.

**Milestone check:** `kubectl get nodes` ready; from inside the pod,
`aws secretsmanager get-secret-value` returns the secret (misconfig live).

---

## Key Misconfigs

Minimal set to make the Phase 10 breach work. Fix them in reverse in Phase 11.

| #   | Misconfig                                | Why needed                          | Phase 11 fix                                             |
| --- | ---------------------------------------- | ----------------------------------- | -------------------------------------------------------- |
| 1   | Broad IAM policy on the pod's IRSA role  | RCE inherits it → read any secret   | Scope to `GetSecretValue` on the one secret ARN          |
| 2   | Loose IRSA trust policy (wildcard `sub`) | Lets the pod assume the broad role  | Pin `sub` to the SA + `aud = sts.amazonaws.com`          |
| 3   | EKS audit logs / CloudTrail off          | Breach is silent (cloud detect gap) | Enable audit + authenticator logs, CloudTrail (optional) |

- **1 + 2** are the exploit. **3** is optional realism — enabling it in Phase 11
  is the cloud-level _detect_ win (parallels the Phase 4 Slack alert).

---

## Keep Secure (do not regress)

Build these correctly in Phase 9 — they keep the chain clean and in scope:

- **IMDSv2 required + hop-limit = 1** on the node group — forces the intended
  IRSA path; otherwise RCE steals the **node** role via IMDS instead.
- **Private subnets for nodes; RDS SG scoped to the node SG** — contains blast
  radius.
- **Existing in-cluster hardening** (RBAC, PSS, NP, no auto-mounted SA token).

---

## Shortened Attack Chain

```txt
React2Shell RCE in pod
  └─▶ pod's IRSA role  (dev attached a broad policy)        [misconfig 1 + 2]
        └─▶ aws secretsmanager get-secret-value <rds-secret>
              └─▶ 🪙 RDS secret
```

- One misconfig, one API call — typed straight into the RCE shell.
- **Fix (reverse):** scope the IAM policy → pin the trust policy.
- **Result:** same call returns `AccessDeniedException` — the cloud mirror of the
  cluster's `403 secrets is forbidden`.

---

## EKS

```sh
terraform -chdir=infra/eks init -backend-config=backend.hcl -upgrade
terraform -chdir=infra/eks fmt && terraform -chdir=infra/eks validate
terraform -chdir=infra/eks plan

terraform -chdir=infra/eks apply -auto-approve
terraform -chdir=infra/eks refresh
terraform -chdir=infra/eks output

terraform -chdir=infra/eks destroy -auto-approve
```
