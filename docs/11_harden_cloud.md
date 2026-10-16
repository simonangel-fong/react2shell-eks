# reat2shell: harden cloud

[Back](../README.md)

- [reat2shell: harden cloud](#reat2shell-harden-cloud)
  - [Goal](#goal)
  - [Harden Steps](#harden-steps)
  - [Proof](#proof)
  - [Shift Left: Scan Terraform](#shift-left-scan-terraform)

---

## Goal

Reverse the Phase 10 chain at its one real link: the over-permissioned pod
identity. Scope the IRSA policy to least privilege — the cloud mirror of the
cluster-level RBAC fix (`403 secrets is forbidden`).

- Scope: **IAM only** (headline fix). Logging / SG / VPC deferred.
- Target: the broad `*/*` role on SA `insecure-frontend:react2shell`.

---

## Harden Steps

Fix the chain in reverse. Isolated to `infra/eks/09_irsa.tf`.

| #   | Step               | What                                                   | Result                              |
| --- | ------------------ | ------------------------------------------------------ | ----------------------------------- |
| 1   | Scope the policy   | `Action:* Resource:*` → `GetSecretValue` on the secret | Broad reach gone                    |
| 2   | Reference the ARN  | Resource = `aws_secretsmanager_secret.rds.arn`         | Stays correct if secret recreated   |
| 3   | Verify trust       | Keep `sub` + `aud` conditions (one SA only)            | No other pod can assume the role    |
| 4   | apply + re-breach  | `terraform apply`, re-run Phase 10 commands            | Breach contained                    |

---

## Proof

Same pod, same `steal_secret.js` — only the IAM policy changed.

| Action                      | Before (phase 10) | After (phase 11)        |
| --------------------------- | ----------------- | ----------------------- |
| `node /tmp/s.js` (get RDS)  | 🪙 secret         | 🪙 secret (legit read)  |
| `node /tmp/s.js --list`     | lists secrets     | `AccessDeniedException` |

- The intended read still works (app not broken); the **broad reach is gone**.
- Cloud mirror of the cluster-level `403 secrets is forbidden`.

**Milestone:** secure at cloud level.

---

## Shift Left: Scan Terraform

Catch IAM misconfig at the PR, before apply — extends the Phase 8 pattern
(`trivy config` on manifests) to the terraform. Reuses the same action, so one
tool covers image + manifest + IaC.

| #   | Step              | What                                                  | Result                          |
| --- | ----------------- | ----------------------------------------------------- | ------------------------------- |
| 1   | New workflow      | `scan-terraform.yml`, triggered on `infra/**` changes | TF scanned on every PR          |
| 2   | Trivy config scan | `trivy config infra/eks`, `severity: HIGH,CRITICAL`   | Flags wildcard IAM, open config |
| 3   | Gate the PR       | Fail the job on findings                               | Insecure terraform rejected     |
| 4   | Accept exceptions | `infra/eks/.trivyignore` for reviewed cases           | Intentional configs documented  |

- Mirrors Phase 8: _insecure push gets rejected_ — now for IaC.
- Same `aquasecurity/trivy-action`, same severity gate already used for images
  and manifests.

