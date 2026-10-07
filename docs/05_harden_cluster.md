# reat2shell: harden cluster

[Back](../README.md)

- [reat2shell: harden cluster](#reat2shell-harden-cluster)
  - [Cluster Harden](#cluster-harden)
  - [Step](#step)
  - [Network Policy](#network-policy)

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
| 3   | PSS                   | ns insecure label; delete existing pod and no recreated due to pss   |
| 4   | kyverno imagepolicy   | new deploy with vulnerable image cannot be launched                  |

---

## Network Policy

- goal:
  - isolate connection between namepsaces
  - the `insecure` pod can no longer curl it.

```sh
# before: insecure pod can reach prod api
python scripts/rce.py http://localhost:8080 "curl -s -m 5 http://nginx-api.prod/api/v1/healthz"
# {"status":"healthy","message":"Service is running"}

# apply default-deny + allow-list in prod, then retry -> times out
python scripts/rce.py http://localhost:8080 "curl -s -m 5 http://nginx-api.prod/api/v1/healthz"
# (no response / timeout)
```
