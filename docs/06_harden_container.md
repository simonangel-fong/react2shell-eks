# reat2shell: harden container

[Back](../README.md)

- [reat2shell: harden container](#reat2shell-harden-container)
  - [Container Harden](#container-harden)
  - [Step](#step)
  - [SA Token](#sa-token)
  - [Security context](#security-context)
  - [PSS](#pss)

---

## Container Harden

- SA
- Security context
- PSS

---

## Step

| #   | Step              | Milestone                                                                     |
| --- | ----------------- | ----------------------------------------------------------------------------- |
| 1   | SA dismount token | vulnerable pod cannot access apiserver                                        |
| 2   | Security context  | vulnerable pod cannot run as root, ecalate priviledge, write root file system |
| 3   | PSS               | new pod not meet pss cannot provision                                         |

---

## SA Token

- `automountServiceAccountToken: false`

```sh
# restart after sync
kubectl -n secure-frontend rollout restart deploy/react2shell

# directory should be gone
kubectl -n secure-frontend exec deploy/react2shell -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
# ls: cannot access '/var/run/secrets/kubernetes.io/serviceaccount/': No such file or directory
# command terminated with exit code 2

# RCE: request api
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header \"Authorization: Bearer ${TOKEN}\" -X GET ${APISERVER}/api"
# executable response:
# curl: (77) error setting certificate file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# RCE: get token
python scripts/rce.py http://localhost:8080 "cat /var/run/secrets/kubernetes.io/serviceaccount/token"
# executable response:
# cat: /var/run/secrets/kubernetes.io/serviceaccount/token: No such file or directory
```

---

## Security context

- pod:
  - `runAsNonRoot: true`
  - `runAsUser: 1000`
  - `runAsGroup: 1000`
  - `fsGroup: 1000`
  - `seccompProfile.type: RuntimeDefault`

- container:
  - `allowPrivilegeEscalation: false`
  - `privileged: false`
  - `readOnlyRootFilesystem: true`
  - `capabilities.drop: ["ALL"]`

```sh
# RCE:user id
python scripts/rce.py http://localhost:8080 id
# executable response:
# uid=1000(node) gid=1000(node) groups=1000(node)

# RCE: read-only fs
python scripts/rce.py http://localhost:8080 "touch /etc/x"
# executable response:
# touch: cannot touch '/etc/x': Read-only file system

# RCE: no priviledge
python scripts/rce.py http://localhost:8080 "sudo touch /etc/x"
# executable response:
# /bin/sh: 1: sudo: not found

# RCE: still get pod tier flag
python scripts/rce.py http://localhost:8080 "printenv CONTAINER_SECRET"
# executable response:
# CoNtAinEr-sEcRet-sECurE
```

---

## PSS

- enforce Pod Security Standards `restricted` via namespace labels.

```sh
# label is applied
kubectl get ns secure-frontend --show-labels

# hardened app still runs
kubectl -n secure-frontend get pods

# a non-conformant pod is REJECTED
kubectl -n secure-frontend run bad --image=nginx:1.27
# Error from server (Forbidden): pods "bad" is forbidden: violates PodSecurity
# "restricted:latest": allowPrivilegeEscalation != false, unrestricted capabilities,
# runAsNonRoot != true, seccompProfile ...
```
