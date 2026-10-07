# reat2shell: local breach

[Back](../README.md)

- [reat2shell: local breach](#reat2shell-local-breach)
  - [Architecture](#architecture)
  - [Steps](#steps)
  - [Install Falco](#install-falco)
    - [helm](#helm)
    - [Argo CD](#argo-cd)
    - [Custome falco](#custome-falco)
      - [1. apiserver audit wiring (kind — needs cluster recreate)](#1-apiserver-audit-wiring-kind--needs-cluster-recreate)
      - [2. Falco k8saudit + custom rule (GitOps)](#2-falco-k8saudit--custom-rule-gitops)
      - [3. Replay the breach → CRITICAL alert](#3-replay-the-breach--critical-alert)

---

## Architecture

```txt
 syscalls ──▶ Falco (DaemonSet, modern_ebpf)
                 │ rule match (JSON event)
                 ▼
            Falcosidekick ──▶ Loki (push API)
                                 │
                 Grafana  ◀──────┘  (Loki datasource)
                    │ alert rule (LogQL: priority=Warning|Critical)
                    ▼
                 Slack  (contact point = Incoming Webhook)
```

## Steps

| #   | Step                                         | Milestone                               |
| --- | -------------------------------------------- | --------------------------------------- |
| 1   | Install Falco app with Falcosidekick         | falco running                           |
| 2   | Create custom Falco rules                    | behavior get log                        |
| 3   | Install Loki + grafana; associate with falco | show violation in grafana               |
| 4   | Setup alert to Slack                         | Slack shows cricital alert              |
| 5   | replay RCE                                   | slask alert on cluster secret operation |
| 6   | Document                                     | key commands get log                    |

Note:

- Only setup monitoring rule for cluster secret as the last resort
  - the trigger of the following cluster hardening

---

## Install Falco

### helm

```sh
# add repo
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update falcosecurity

# install falco + falcosidekick
helm install falco falcosecurity/falco \
    --namespace monitoring --create-namespace \
    --set driver.kind=modern_ebpf \
    --set tty=true \
    --set falcosidekick.enabled=true \
    --set falcosidekick.webui.enabled=false

# verify
kubectl -n monitoring get pods
# NAME                                   READY   STATUS    RESTARTS   AGE
# falco-falcosidekick-84b6cccd64-hdtbq   1/1     Running   0          3m7s
# falco-falcosidekick-84b6cccd64-qb7ft   1/1     Running   0          3m7s
# falco-fz447                            2/2     Running   0          3m7s
# falco-q86dm                            2/2     Running   0          3m7s
```

### Argo CD

- `argocd/apps/platform.yaml`
- `argocd/platform/falco.yaml`

```sh
kubectl get app falco -n argocd
# NAME    SYNC STATUS   HEALTH STATUS
# falco   Synced        Healthy

kubectl -n monitoring get pods
# NAME                                   READY   STATUS    RESTARTS   AGE
# falco-7tkzv                            2/2     Running   0          113s
# falco-falcosidekick-84b6cccd64-52clc   1/1     Running   0          113s
# falco-falcosidekick-84b6cccd64-bt744   1/1     Running   0          113s
# falco-xbbq5                            2/2     Running   0          113s
```

---

### Custome falco

- falco rule monitorin the cluster secret access

The cluster-secret read (breach step 4) is a **K8s API call** — the stolen SA
token does `GET /api/v1/namespaces/prod/secrets`. That is not a node syscall, so
the syscall driver can't see it. Falco observes it through the **k8saudit
plugin**, which needs the apiserver to emit audit events to Falco's webserver.

```txt
apiserver --(audit webhook)--> localhost:30007/k8s-audit --> Falco (k8saudit plugin)
                                                                 │ rule match
                                                                 ▼
                                                           Falcosidekick --> Loki
```

#### 1. apiserver audit wiring (kind — needs cluster recreate)

Audit flags can't be added to a running kind cluster, so the cluster is
recreated with the audit policy + webhook mounted into the control-plane node.

- `kind/audit-policy.yaml` — log Secret access at Metadata level, drop the rest
- `kind/audit-webhook.yaml` — apiserver POSTs to `http://localhost:30007/k8s-audit`
- `kind/kind-config.yaml` — `extraMounts` + `apiServer.extraArgs` audit flags

```sh
# recreate the cluster (run from repo root so ./kind/ paths resolve)
kind delete cluster --name react2shell-eks
kind create cluster --config kind/kind-config.yaml

# confirm apiserver picked up the audit flags
docker exec react2shell-eks-control-plane \
  grep audit /etc/kubernetes/manifests/kube-apiserver.yaml
# - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
# - --audit-webhook-config-file=/etc/kubernetes/audit/audit-webhook.yaml
# - --audit-webhook-batch-max-wait=5s
```

#### 2. Falco k8saudit + custom rule (GitOps)

`argocd/platform/falco.yaml` loads the chart's `values-syscall-k8saudit.yaml`
profile, exposes the k8saudit webserver on NodePort `30007`, and ships the
custom rule via `customRules`:

```yaml
- rule: Cluster Secret Accessed via K8s API
  desc: A Secret in the prod namespace was read/listed through the K8s API.
  condition: >
    ka.verb in (get, list, watch)
    and ka.target.resource = secrets
    and ka.target.namespace = prod
  output: >
    Cluster secret accessed in prod ns
    (verb=%ka.verb user=%ka.user.name resource=%ka.target.resource
    ns=%ka.target.namespace name=%ka.target.name source=%ka.sourceips)
  priority: CRITICAL
  source: k8s_audit
  tags: [k8s, secrets, react2shell, cluster-jewel]
```

```sh
# sync via argocd, then verify the plugin + NodePort
kubectl -n argocd get app falco
# NAME    SYNC STATUS   HEALTH STATUS
# falco   Synced        Healthy

kubectl -n monitoring get svc falco
# NAME    TYPE       CLUSTER-IP      PORT(S)          AGE
# falco   NodePort   10.96.x.x       9765:30007/TCP   1m

kubectl -n monitoring logs ds/falco -c falco | grep -i k8saudit
# Loaded plugin 'k8saudit' ...
# Starting webserver, listening on port 9765
```

#### 3. Replay the breach → CRITICAL alert

```sh
# stolen SA token lists secrets in the prod ns (breach step 4)
python scripts/rce.py http://localhost:8080 "APISERVER=https://kubernetes.default.svc;SA=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=\$(cat \$SA/token);curl -sS --cacert \$SA/ca.crt -H \"Authorization: Bearer \$TOKEN\" \$APISERVER/api/v1/namespaces/prod/secrets"

# Falco fires (tail the pod to confirm before wiring Loki/Grafana)
kubectl -n monitoring logs -f ds/falco -c falco | grep -i "Cluster secret"
# Critical Cluster secret accessed in prod ns (verb=list user=system:serviceaccount:insecure:react2shell resource=secrets ns=prod name= source=[...])
```

> Note: on kind the apiserver is a static pod on the control-plane node's host
> network, so `localhost:30007` reaches the NodePort. If no audit events arrive,
> check the `falco` svc shows `30007` and the k8saudit plugin logs "listening".
