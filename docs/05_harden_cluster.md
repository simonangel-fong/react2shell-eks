# reat2shell: harden cluster

[Back](../README.md)

- [reat2shell: harden cluster](#reat2shell-harden-cluster)
  - [Cluster Harden](#cluster-harden)
  - [Step](#step)
  - [Network Policy](#network-policy)
  - [RBAC](#rbac)
  - [Kyverno](#kyverno)
    - [Install with helm](#install-with-helm)
    - [Argo CD](#argo-cd)
    - [Kyverno CLI](#kyverno-cli)

---

## Cluster Harden

- NP
- RBAC,
- PSS + imagepolicy(Kyverno)

---

## Step

| #   | Step                  | Milestone                                                            |
| --- | --------------------- | -------------------------------------------------------------------- |
| 1   | Create Network policy | api in prod ns is isolated                                           |
| 2   | RBAC                  | vulnerable pod cannot access cluster secret and associated resources |
| 3   | kyverno imagepolicy   | new deploy with vulnerable image cannot be launched                  |

---

## Network Policy

- goal:
  - isolate connection between namepsaces
  - the `insecure` pod can no longer curl it.

```sh
# ##############################
# insecure: can reach backend api
# ##############################
python scripts/rce.py http://localhost:8000 "curl -sS -m 5 http://backend-api.insecure-backend/api/v1/healthz"
# {"status":"healthy","message":"Service is running"}

python scripts/rce.py http://localhost:8000 "curl -sS -m 5 http://backend-api.insecure-backend/api/v1/users"
# [{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]

# ##############################
# Secure: access fails
# ##############################
kubectl get netpol -n secure-backend
# NAME                        POD-SELECTOR    AGE
# allow-dns-egress            <none>          81s
# allow-nginx-api-from-prod   app=nginx-api   81s
# default-deny-all            <none>          81s

python scripts/rce.py http://localhost:8080 "curl -sS -m 5 http://backend-api.secure-backend/api/v1/healthz"
# curl: (28) Connection timed out after 5000 milliseconds

python scripts/rce.py http://localhost:8080 "curl -sS -m 5 http://backend-api.secure-backend/api/v1/users"
# curl: (28) Connection timed out after 5001 milliseconds
```

---

## RBAC

- drop unneccessary cluster role and clusterrolebinding, role and rolebinding

```sh
# confirm
# list
kubectl auth can-i --list --as=system:serviceaccount:secure-frontend:react2shell -n secure-frontend
# Resources                                       Non-Resource URLs                      Resource Names   Verbs
# selfsubjectreviews.authentication.k8s.io        []                                     []               [create]
# selfsubjectaccessreviews.authorization.k8s.io   []                                     []               [create]
# selfsubjectrulesreviews.authorization.k8s.io    []                                     []               [create]
#                                                 [/.well-known/openid-configuration/]   []               [get]
#                                                 [/.well-known/openid-configuration]    []               [get]
#                                                 [/api/*]                               []               [get]
#                                                 [/api]                                 []               [get]
#                                                 [/apis/*]                              []               [get]
#                                                 [/apis]                                []               [get]
#                                                 [/healthz]                             []               [get]
#                                                 [/healthz]                             []               [get]
#                                                 [/livez]                               []               [get]
#                                                 [/livez]                               []               [get]
#                                                 [/openapi/*]                           []               [get]
#                                                 [/openapi]                             []               [get]
#                                                 [/openid/v1/jwks/]                     []               [get]
#                                                 [/openid/v1/jwks]                      []               [get]
#                                                 [/readyz]                              []               [get]
#                                                 [/readyz]                              []               [get]
#                                                 [/version/]                            []               [get]
#                                                 [/version/]                            []               [get]
#                                                 [/version]                             []               [get]
#                                                 [/version]                             []               [get]

# list secrets
kubectl auth can-i list secrets --all-namespaces --as=system:serviceaccount:secure-frontend:react2shell
# no

```

- rce

```sh
# insecure
python scripts/rce.py http://localhost:8000 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/secrets"
      # "data": {
      #   "password": "Q29OdEFpbkVyLXNFY1JldC1zRUN1ckU="
      # },
      # "type": "Opaque"

# secure: cannot query secrets
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/secrets"
# {
#   "kind": "Status",
#   "apiVersion": "v1",
#   "metadata": {},
#   "status": "Failure",
#   "message": "secrets is forbidden: User \"system:serviceaccount:secure-frontend:react2shell\" cannot list resource \"secrets\" in API group \"\" at the cluster scope",
#   "reason": "Forbidden",
#   "details": {
#     "kind": "secrets"
#   },
#   "code": 403
# }

# secure: cannot query ns
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces"
# {
#   "kind": "Status",
#   "apiVersion": "v1",
#   "metadata": {},
#   "status": "Failure",
#   "message": "namespaces is forbidden: User \"system:serviceaccount:secure-frontend:react2shell\" cannot list resource \"namespaces\" in API group \"\" at the cluster scope",
#   "reason": "Forbidden",
#   "details": {
#     "kind": "namespaces"
#   },
#   "code": 403
# }


```

## Kyverno

### Install with helm

```sh
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# confirm
k get po -n kyverno
# NAME                                             READY   STATUS    RESTARTS   AGE
# kyverno-admission-controller-86cbbb5545-4str2    1/1     Running   0          2m33s
# kyverno-background-controller-5546cb5b76-jmll6   1/1     Running   0          2m33s
# kyverno-cleanup-controller-f947f9769-bvqg6       1/1     Running   0          2m33s
# kyverno-reports-controller-79d68cccbb-756qf      1/1     Running   0          2m33s

# clean up
helm uninstall kyverno -n kyverno
```

---

### Argo CD

- `argocd/platform/kyverno.yaml`: install kyverno
- `argocd/platform/kyverno-image-policy.yaml`: image policy
  - must use docker registry
  - must use tag
  - must not use latest
  - must not use vulerable tag

```sh
# confirm
kubectl get ValidatingPolicy
# NAME           AGE   READY
# image-policy   14m   true

kubectl -n insecure-frontend run bad --image=docker.io/simonangelfong/react2shell:insecure --dry-run=server
# Error from server: admission webhook "vpol.validate.kyverno.svc-fail" denied the request: Policy image-policy failed: the :insecure image tag is forbidden

kubectl -n insecure-frontend run bad --image=nginx:latest --dry-run=server
# Error from server: admission webhook "vpol.validate.kyverno.svc-fail" denied the request: Policy image-policy failed: image must not use the :latest tag

kubectl -n insecure-frontend run ok --image=nginx:1.27 --dry-run=server
# pod/ok created (server dry run)
```

---

### Kyverno CLI

- shift-left: run the same `ValidatingPolicy` offline against Pod manifests.
- scan only Pod-bearing files — the CEL CLI errors if CRDs (Argo/Kyverno
  Applications) are in the resource set.

```sh
# install WSL — ValidatingPolicy
curl -LO https://github.com/kyverno/kyverno/releases/download/v1.19.1/kyverno-cli_v1.19.1_linux_x86_64.tar.gz
tar -xvf kyverno-cli_v1.19.1_linux_x86_64.tar.gz
sudo cp kyverno /usr/local/bin/

# confirm
kyverno version
# Version: 1.19.1
# Time: 2026-09-10T05:20:21Z
# Git commit ID: 40ec788d48bb28d83dbf85538e962a59db9d45c6

# apply the image policy to the deploy manifests
kyverno apply argocd/platform/kyverno-image-policy.yaml \
  --resource argocd/secure-frontend/deploy.yaml \
  --resource argocd/insecure-frontend/deploy.yaml

# Applying 1 policy rule(s) to 2 resource(s)...
# pass: 2, fail: 0, warn: 0, error: 0, skip: 0
```
