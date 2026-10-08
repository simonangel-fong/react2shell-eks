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
kubectl -n secure-frontend rollout restart deploy/react2shell
kubectl -n secure-frontend rollout status deploy/react2shell --timeout=120s

python scripts/rce.py http://localhost:8080 id            # uid=1000 (non-root)
python scripts/rce.py http://localhost:8080 "touch /etc/x"  # read-only error (rootfs still RO elsewhere)

```


## PSS
