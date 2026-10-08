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
# -> No such file or directory

# via RCE: token read fails
python scripts/rce.py http://localhost:8080 "cat /var/run/secrets/kubernetes.io/serviceaccount/token"
# -> (empty / no such file)

```

## Security context

## PSS
