# reat2shell: harden cluster

[Back](../README.md)

- [reat2shell: harden cluster](#reat2shell-harden-cluster)
  - [Cluster Harden](#cluster-harden)
  - [Step](#step)
  - [Network Policy](#network-policy)
    - [Install Calico](#install-calico)
  - [RBAC](#rbac)

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

### Install Calico

```sh
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml

k get node
# NAME                            STATUS   ROLES           AGE   VERSION
# react2shell-eks-control-plane   Ready    control-plane   14m   v1.35.0
# react2shell-eks-worker          Ready    <none>          14m   v1.35.0
```

```sh
# ##############################
# before: insecure pod can reach prod api
# ##############################
python scripts/rce.py http://localhost:8080 "curl -m 5 http://nginx-api.prod/api/v1/healthz"
# {"status":"healthy","message":"Service is running"}

# ##############################
# apply default-deny + allow-list in prod, then retry -> times out
# ##############################
kubectl get netpol -n prod
# NAME                        POD-SELECTOR    AGE
# allow-dns-egress            <none>          81s
# allow-nginx-api-from-prod   app=nginx-api   81s
# default-deny-all            <none>          81s

kubectl get netpol -n insecure
# NAME                POD-SELECTOR      AGE
# allow-app-ingress   app=react2shell   109s
# allow-dns-egress    <none>            109s
# default-deny-all    <none>            109s

python scripts/rce.py http://localhost:8080 "curl -S -m 5 http://nginx-api.prod/api/v1/healthz"
# curl: (28) Connection timed out after 5000 milliseconds
```

---

## RBAC

