# reat2shell: Cluster hardening

[Back](../README.md)

- [reat2shell: Cluster hardening](#reat2shell-cluster-hardening)
  - [Overview](#overview)
    - [Steps](#steps)
  - [Cloud layer hardening](#cloud-layer-hardening)
    - [Root cause analysis](#root-cause-analysis)
    - [Setup environment](#setup-environment)
    - [Confirm](#confirm)
  - [Cluster layer hardening](#cluster-layer-hardening)
    - [Root cause analysis](#root-cause-analysis-1)
    - [Setup environment](#setup-environment-1)
    - [Confirm](#confirm-1)
  - [Container layer hardening](#container-layer-hardening)
    - [Root cause analysis](#root-cause-analysis-2)
    - [Setup environment](#setup-environment-2)
    - [Confirm](#confirm-2)
  - [Code lay hardening](#code-lay-hardening)
    - [Root cause analysis](#root-cause-analysis-3)
    - [Setup environment](#setup-environment-3)
    - [Confirm](#confirm-3)

---

## Overview

- Perspective: Cluster security specialist
- Goal: show how to harden a cluster
- Url: `http://react2shell.arguswatcher.net:3000`

---

### Steps

| #   | Steps                       | Layers    | Env                                  | Milestone                           |
| --- | --------------------------- | --------- | ------------------------------------ | ----------------------------------- |
| 0   | Harden cloud with terraform | cloud     | eks-secure + insecure-apps-cloud     | secure RDS secret                   |
| 1   | Harden cluster              | cluster   | eks-secure + insecure-apps-cluster   | secure cluster secret, internal api |
| 2   | Harden container            | container | eks-secure + insecure-apps-container | secure sa token, apiserver, ESO     |
| 3   | Harden code                 | code      | eks-secure + secure-apps             | disable exploit                     |

---

## Cloud layer hardening

### Root cause analysis

- Issues:
  - EKS pod is granted access to secretmanager
  - AWS context get injected into the pod
- Root cause
  - broad IRSA `*/*`
  - pod annotation with aws role
- Fix
  - Remove `pod-irsa` role

---

### Setup environment

- Environment:
  - infra: eks-secure
  - manifests: insecure-apps-cloud

```sh
# trivy scan
trivy config infra/eks-secure --severity HIGH,CRITICAL

# provision eks cluster
terraform -chdir=infra/eks-secure apply -auto-approve
aws eks update-kubeconfig --region ca-central-1 --name react2shell-eks-secure

# deploy apps
kubectl apply -f argocd/insecure-root-app-cloud.yaml
# port forward
kubectl port-forward service/react2shell -n react 3000:3000
```

---

### Confirm

```sh
VICTIM_URL="http://react2shell.arguswatcher.net:3000"

# ##############################
# Attack
# ##############################
# 1. confirm RCE by id — app still vulnerable (code/container/cluster unhardened)
python scripts/rce.py $VICTIM_URL "id"
# uid=0(root) gid=0(root) groups=0(root)

# 2. look for an AWS identity — none projected (annotation removed, role gone)
python3 scripts/rce.py $VICTIM_URL "env | grep AWS"
# (no output) — no AWS_ROLE_ARN / AWS_WEB_IDENTITY_TOKEN_FILE

# 3. upload js
b64=$(base64 -w0 scripts/steal_secret.js)
python3 scripts/rce.py $VICTIM_URL "echo $b64 | base64 -d > /tmp/s.js"

# 4. try to grab the jewel — no credentials to assume any role
python3 scripts/rce.py $VICTIM_URL "node /tmp/s.js --list"
# fails: no IRSA env (AWS_ROLE_ARN / AWS_WEB_IDENTITY_TOKEN_FILE)
```

---

## Cluster layer hardening

### Root cause analysis

| Issue | Root cause | fix |
| ----- | ---------- | --- |
|       | IAM        |     |
|       | IRSA       |     |

---

### Setup environment

- Environment:
  - infra: eks-secure
  - manifests: insecure-apps-cluster

```sh
# provision eks cluster
terraform -chdir=infra/eks-secure apply -auto-approve
aws eks update-kubeconfig --region ca-central-1 --name react2shell-eks-insecure

# deploy apps
kubectl apply -f argocd/insecure-root-app-cluster.yaml
# port forward
kubectl port-forward service/react2shell -n react 3000:3000
```

---

### Confirm

```sh

```

---

## Container layer hardening

### Root cause analysis

| Issue | Root cause | fix |
| ----- | ---------- | --- |
|       | IAM        |     |
|       | IRSA       |     |

---

### Setup environment

- Environment:
  - infra: eks-secure
  - manifests: insecure-apps-container

```sh
# provision eks cluster
terraform -chdir=infra/eks-secure apply -auto-approve
aws eks update-kubeconfig --region ca-central-1 --name react2shell-eks-insecure

# deploy apps
kubectl apply -f argocd/insecure-root-app-container.yaml
# port forward
kubectl port-forward service/react2shell -n react 3000:3000
```

---

### Confirm

```sh

```

---

## Code lay hardening

### Root cause analysis

| Issue | Root cause | fix |
| ----- | ---------- | --- |
|       | IAM        |     |
|       | IRSA       |     |

---

### Setup environment

- Environment:
  - infra: eks-secure
  - manifests: secure-apps

```sh
# provision eks cluster
terraform -chdir=infra/eks-secure apply -auto-approve
aws eks update-kubeconfig --region ca-central-1 --name react2shell-eks-insecure

# deploy apps
kubectl apply -f argocd/secure-root-app.yaml
# port forward
kubectl port-forward service/react2shell -n react 3000:3000
```

---

### Confirm

```sh

```

---
