# reat2shell: Incident Response

[Back](../README.md)

- [reat2shell: Incident Response](#reat2shell-incident-response)
  - [Overview](#overview)
    - [Steps](#steps)
  - [Setup Environment](#setup-environment)
  - [Indicators of Compromise](#indicators-of-compromise)
    - [Routine inspection](#routine-inspection)
    - [Source IP check](#source-ip-check)
    - [Identify resources involved](#identify-resources-involved)
    - [Behavior profiling](#behavior-profiling)
    - [Cross check confirm: pod log](#cross-check-confirm-pod-log)
  - [Short-term Containment](#short-term-containment)
    - [Disable Argo CD auto-sync](#disable-argo-cd-auto-sync)
    - [Collect evidence](#collect-evidence)
    - [Remove the pod from the Service](#remove-the-pod-from-the-service)
    - [Isolate by network policy](#isolate-by-network-policy)
    - [Cordon inffected node](#cordon-inffected-node)
  - [Incident Response Report](#incident-response-report)
    - [Summary](#summary)
    - [Timeline (UTC)](#timeline-utc)
    - [Findings](#findings)
    - [Containment actions taken](#containment-actions-taken)
    - [Actions requires elevated permissions](#actions-requires-elevated-permissions)

---

## Overview

- **Perspective**: Platform admin
- **Goal**: show how a platform admin respond to a breach
- **Environment**:
  - infra: eks-insecure
  - manifests: insecure-apps
- **Url**: `http://react2shell.arguswatcher.net:3000`

---

### Steps

| #   | Steps                    | Milestone                                                 |
| --- | ------------------------ | --------------------------------------------------------- |
| 0   | Setup Environment        | EKS cluster & React app                                   |
| 1   | Indicators of Compromise | confirm breach by log;                                    |
| 2   | Short-Term Containment   | Identify thread source; scale down compromised components |
| 3   | Incident Response Report | Incident Response Report                                  |

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

---

## Indicators of Compromise

- Timestamp: Day 1 20:15
- Role: platform engineer
- Task: Routine inspection
- Tools:
  - `CloudTrail`: AWS service that tracks and audits user activity and API calls for security and compliance

---

### Routine inspection

- Routine inspection against `AssumeRoleWithWebIdentity`
  - `AWS Security Token Service (STS) API` operation that exchanges a validated web identity token
  - the event of which is an important indicator of compromise, like the unknown request over `STS API`

```sh
# show uptime of admin machine
uptime
# 20:17:57 up 21:30,  1 user,  load average: 0.16, 0.24, 0.34

# get the event of last 3 hours
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --start-time "$(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --query 'Events[].{time:EventTime,user:Username}' \
  --output table

# --------------------------------------------------------------------------
# |                              LookupEvents                              |
# +----------------------------+-------------------------------------------+
# |            time            |                   user                    |
# +----------------------------+-------------------------------------------+
# |  2026-10-18T20:14:24-04:00 |  system:serviceaccount:react:react2shell  |
# |  2026-10-18T20:14:21-04:00 |  system:serviceaccount:react:react2shell  |
# |  2026-10-18T20:10:45-04:00 |  system:serviceaccount:react:react2shell  |
# |  2026-10-18T20:10:36-04:00 |  system:serviceaccount:react:react2shell  |
# +----------------------------+-------------------------------------------+

# Get the full event records
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --start-time 2026-10-18T20:00:00Z \
  --query 'Events[].CloudTrailEvent' --output text | jq .
```

---

- The events of `AssumeRoleWithWebIdentity` shows
  - unseen user `system:serviceaccount:react:react2shell`
  - suspecious behavior: 4 accesses in 4 minutes

![webid_event](./img/platform_admin/webid_event.png)

- Full event summary:

| time (UTC)     | source IP   | OIDC provider id | webIdentityTokenId | accessKeyId   | iam role                               |
| -------------- | ----------- | ---------------- | ------------------ | ------------- | -------------------------------------- |
| 10-19 00:10:36 | 16.54.55.36 | 6F5CAE…8DED      | 39f92e76…          | ASIA…GQ763IBU | role/react2shell-eks-insecure-pod-irsa |
| 10-19 00:10:45 | 16.54.55.36 | 6F5CAE…8DED      | 39f92e76…          | ASIA…AMVADZXK | role/react2shell-eks-insecure-pod-irsa |
| 10-19 00:14:21 | 16.54.55.36 | 6F5CAE…8DED      | 39f92e76…          | ASIA…ERUHF35F | role/react2shell-eks-insecure-pod-irsa |
| 10-19 00:14:24 | 16.54.55.36 | 6F5CAE…8DED      | 39f92e76…          | ASIA…CWCAM    | role/react2shell-eks-insecure-pod-irsa |

![webid_event](./img/platform_admin/webid_event_full.png)

---

### Source IP check

- Check IP whether from internal or external
  - from NAT public IP used by EKS
  - the calls originated inside the cluster

```sh
aws ec2 describe-nat-gateways \
  --query 'NatGateways[].{id:NatGatewayId,ip:NatGatewayAddresses[].PublicIp}' \
  --output table

# ---------------------------
# |   DescribeNatGateways   |
# +-------------------------+
# |           id            |
# +-------------------------+
# |  nat-0e3f343176e02b451  |
# +-------------------------+
# ||          ip           ||
# |+-----------------------+|
# ||  16.54.55.36          ||
# |+-----------------------+|
```

![webid_ip_check](./img/platform_admin/webid_ip_check.png)

---

### Identify resources involved

```sh
# idenfity what each session actually did.
# loop session keys
for k in ASIAROFJQB4XGQ763IBU ASIAROFJQB4XAMVADZXK ASIAROFJQB4XERUHF35F ASIAROFJQB4XJ2ACWCAM;
do
  echo "=== $k ==="
  aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=$k \
    --start-time 2026-10-19T00:00:00Z \
    --query 'Events[].{time:EventTime,event:EventName,res:Resources[0].ResourceName}' \
    --output table
done

# === ASIAROFJQB4XGQ763IBU ===
# ------------------------------------------------------
# |                    LookupEvents                    |
# +--------------+-------+-----------------------------+
# |     event    |  res  |            time             |
# +--------------+-------+-----------------------------+
# |  ListSecrets |  None |  2026-10-18T20:10:36-04:00  |
# +--------------+-------+-----------------------------+
# === ASIAROFJQB4XAMVADZXK ===
# --------------------------------------------------------------------------------------------
# |                                       LookupEvents                                       |
# +----------------+-------------------------------------------+-----------------------------+
# |      event     |                    res                    |            time             |
# +----------------+-------------------------------------------+-----------------------------+
# |  GetSecretValue|  react2shell-eks-insecure-rds-credential  |  2026-10-18T20:10:45-04:00  |
# +----------------+-------------------------------------------+-----------------------------+
# === ASIAROFJQB4XERUHF35F ===
# --------------------------------------------------------------------------------------------
# |                                       LookupEvents                                       |
# +----------------+-------------------------------------------+-----------------------------+
# |      event     |                    res                    |            time             |
# +----------------+-------------------------------------------+-----------------------------+
# |  GetSecretValue|  react2shell-eks-insecure-rds-credential  |  2026-10-18T20:14:21-04:00  |
# +----------------+-------------------------------------------+-----------------------------+
# === ASIAROFJQB4XJ2ACWCAM ===
# ------------------------------------------------------
# |                    LookupEvents                    |
# +--------------+-------+-----------------------------+
# |     event    |  res  |            time             |
# +--------------+-------+-----------------------------+
# |  ListSecrets |  None |  2026-10-18T20:14:25-04:00  |
# +--------------+-------+-----------------------------+
```

- Action and target summary:

| #   | time (EDT) | action         | target                                  |
| --- | ---------- | -------------- | --------------------------------------- |
| 1   | 20:10:36   | ListSecrets    | (enumerate secrets)                     |
| 2   | 20:10:45   | GetSecretValue | react2shell-eks-insecure-rds-credential |
| 3   | 20:14:21   | GetSecretValue | react2shell-eks-insecure-rds-credential |
| 4   | 20:14:25   | ListSecrets    | (enumerate secrets)                     |

![webid_access_resources](./img/platform_admin/webid_access_resources.png)

---

### Behavior profiling

- Access via `AssumeRoleWithWebIdentity`
  - Four one-hour credentials, four single API calls.
- User: `serviceaccount:react:react2shell`
  - type: service account
  - namespace: `react`
  - service account name: `react2shell`
- Source IP:
  - EKS's NAT gateway, originating from EKS cluster
- Behavior:
  - `ListSecrets` -> `GetSecretValue` -> `GetSecretValue` -> `ListSecrets`
  - looked -> took -> came back -> looked again to see what else was there.

---

### Cross check confirm: pod log

- the user is `system:serviceaccount:react:react2shell`
  - namespace: `react`
  - service account: `react2shell`

```sh
# locate pod with service account
kubectl -n react get pods -o json | jq -r '
  .items[]
  | select(.spec.serviceAccountName=="react2shell")
  | [.metadata.name, .status.startTime, .spec.nodeName,
     (.status.containerStatuses[0].restartCount|tostring)] | @tsv' \
  | column -t

# react2shell-6d4d4db59d-xwtxq  2026-10-19T00:04:05Z  ip-10-0-36-129.ca-central-1.compute.internal  0

# get pod logs
kubectl -n react logs react2shell-6d4d4db59d-xwtxq --since-time=2026-10-19T00:10:00Z --timestamps
# 2026-10-19T00:04:19.885762069Z
# 2026-10-19T00:04:19.885806411Z > react2shell-insecure@0.1.0 dev
# 2026-10-19T00:04:19.885813113Z > next dev -H 0.0.0.0
# 2026-10-19T00:04:19.885815747Z
# 2026-10-19T00:04:21.095144901Z    ▲ Next.js 15.2.2
# 2026-10-19T00:04:21.095607602Z    - Local:        http://localhost:3000
# 2026-10-19T00:04:21.095663779Z    - Network:      http://0.0.0.0:3000
# 2026-10-19T00:04:21.095871874Z
# 2026-10-19T00:04:21.095947692Z  ✓ Starting...
# 2026-10-19T00:04:21.105665963Z  ⚠ Invalid next.config.mjs options detected:
# 2026-10-19T00:04:21.105767123Z  ⚠     Unrecognized key(s) in object: 'cacheComponents', 'partialPrefetching'
# 2026-10-19T00:04:21.105772913Z  ⚠ See more info here: https://nextjs.org/docs/messages/invalid-next-config
# 2026-10-19T00:04:21.166409028Z Attention: Next.js now collects completely anonymous telemetry regarding usage.
# 2026-10-19T00:04:21.166468681Z This information is used to shape Next.js' roadmap and prioritize features.
# 2026-10-19T00:04:21.166475025Z You can learn more, including how to opt-out if you'd not like to participate in this anonymous program, by visiting the following URL:
# 2026-10-19T00:04:21.166542976Z https://nextjs.org/telemetry
# 2026-10-19T00:04:21.166596109Z
# 2026-10-19T00:04:22.703026776Z  ✓ Ready in 1816ms
# 2026-10-19T00:04:38.587514309Z  ○ Compiling / ...
# 2026-10-19T00:04:51.174410971Z  ✓ Compiled / in 13.1s (702 modules)
# ...
# ...
# 2026-10-19T00:14:22.531300448Z  ⨯ [Error: NEXT_REDIRECT] {
# 2026-10-19T00:14:22.531363217Z   digest: '[*] role=arn:aws:iam::099139718958:role/react2shell-eks-insecure-pod-irsa region=ca-central-1 mode=get secret=react2shell-eks-insecure-rds-credential\n' +
# 2026-10-19T00:14:22.531373798Z     '[*] assumed role, akid=ASIAROFJQB4XERUHF35F\n' +
# 2026-10-19T00:14:22.531378153Z     '{"ARN":"arn:aws:secretsmanager:ca-central-1:099139718958:secret:react2shell-eks-insecure-rds-credential-kUbCTo","CreatedDate":1.792366678396E9,"Name":"react2shell-eks-insecure-rds-credential","SecretString":"{\\"dbname\\":\\"appdb\\",\\"engine\\":\\"postgres\\",\\"host\\":\\"placeholder.rds.amazonaws.com\\",\\"password\\":\\"RDS-sECrEt-InsECurE\\",\\"port\\":5432,\\"username\\":\\"rds_admin\\"}","VersionId":"terraform-IJ8NoxhXbcospmuXYyEXEqzAxw","VersionStages":["AWSCURRENT"]}'
# 2026-10-19T00:14:22.531393873Z }
# 2026-10-19T00:14:22.535207512Z  POST / 500 in 1317ms
# 2026-10-19T00:14:25.514221114Z  ⨯ [Error: NEXT_REDIRECT] {
# 2026-10-19T00:14:25.514292956Z   digest: '[*] role=arn:aws:iam::099139718958:role/react2shell-eks-insecure-pod-irsa region=ca-central-1 mode=list\n' +
# 2026-10-19T00:14:25.514298578Z     '[*] assumed role, akid=ASIAROFJQB4XJ2ACWCAM\n' +
# 2026-10-19T00:14:25.514427902Z     '{"SecretList":[{"ARN":"arn:aws:secretsmanager:ca-central-1:099139718958:secret:react2shell-eks-insecure-rds-credential-kUbCTo","CreatedDate":1.79236667788E9,"Description":"RDS master credential (crown jewel).","LastAccessedDate":1.792368E9,"LastChangedDate":1.792366678401E9,"Name":"react2shell-eks-insecure-rds-credential","SecretVersionsToStages":{"terraform-IJ8NoxhXbcospmuXYyEXEqzAxw":["AWSCURRENT"]},"Tags":[{"Key":"Project","Value":"react2shell-eks"},{"Key":"Environment","Value":"insecure"},{"Key":"ManagedBy","Value":"terraform"}]}]}'
# 2026-10-19T00:14:25.514525891Z }
# 2026-10-19T00:14:25.519468490Z  POST / 500 in 795ms
# 2026-10-19T00:15:46.633163739Z  GET / 200 in 86ms
# 2026-10-19T00:15:47.314173546Z  GET /favicon.ico 200 in 218ms
```

---

- Pod log summary:

| Timestamp(UTC)   | Logs                                  | Sensitive data in plaintext                           |
| ---------------- | ------------------------------------- | ----------------------------------------------------- |
| 2026-10-19T00:04 | code compiled and pod started serving |                                                       |
| 2026-10-19T00:10 | POST 500, role arn and secret name    | secret name `react2shell-eks-insecure-rds-credential` |
| 2026-10-19T00:10 | POST 500, role arn and secret value   | secret value `password: RDS-sECrEt-InsECurE`          |
| 2026-10-19T00:14 | POST 500, role arn and secret value   | secret value `password: RDS-sECrEt-InsECurE`          |
| 2026-10-19T00:14 | POST 500, role arn and secret name    | secret name `react2shell-eks-insecure-rds-credential` |

- Pod logs confirm the behaviors found in the `CloudTrail` events
  - list secrets, get the secret values, confirm the secret values, and list secrets.
- **CONCLUSION: Breach occurs and data get leaked.**

![react_pod_logs01](./img/platform_admin/react_pod_logs01.png)

![react_pod_logs02](./img/platform_admin/react_pod_logs02.png)

---

## Short-term Containment

- Goal:
  - stop the attacker acting through the compromised pod,
  - without destroying the evidence it holds
  - The pod stays running — isolated, not deleted.

### Disable Argo CD auto-sync

- The deployment is GitOps-managed.
  - disable argocd auto-sync, preventing the reconciliation

```sh
# Disable Argo CD auto-sync
kubectl -n argocd patch app insecure-root-app --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'

# application.argoproj.io/insecure-root-app patched
kubectl -n argocd get app insecure-root-app -o jsonpath='{.spec.syncPolicy}{"\n"}'
# {"syncOptions":["CreateNamespace=true"]}

# App-of-apps: confirm no parent re-enables it
kubectl -n argocd get app -o custom-columns='NAME:.metadata.name,AUTO:.spec.syncPolicy.automated'
# NAME                 AUTO
# insecure-root-app    <none>
# react2shell          <none>
```

![containment_disable_argocd](./img/platform_admin/containment_disable_argocd.png)

---

### Collect evidence

```sh
# create evidence dir
TS=$(date -u +%Y%m%dT%H%M%SZ); mkdir -p evidence-$TS

# save pod log
kubectl -n react logs react2shell-6d4d4db59d-xwtxq > evidence-$TS/pod.log
kubectl -n react logs -l app=react2shell > evidence-$TS/pod.log
# save pod definition
kubectl -n react get pod react2shell-6d4d4db59d-xwtxq -o yaml > evidence-$TS/pod.yaml
kubectl -n react get pod -l app=react2shell -o yaml > evidence-$TS/pod.yaml
# save event log
kubectl -n react get events --sort-by=.lastTimestamp > evidence-$TS/events.txt

# save decoded SA token
echo $(kubectl -n react exec react2shell-6d4d4db59d-xwtxq -- cat /var/run/secrets/eks.amazonaws.com/serviceaccount/token | cut -d. -f2 | base64 -d 2>/dev/null | jq .) > evidence-$TS/token-decode.txt

# Confirm: count session key in log
grep -c 'akid=ASIA' evidence-$TS/pod.log
# 4
```

---

### Remove the pod from the Service

- Changing the pod's `app` label breaks the Service selector match.
  - Traffic stops immediately;
  - the ReplicaSet schedules a replacement, keeping service running.

```sh
# add pod label
kubectl -n react label pod react2shell-6d4d4db59d-xwtxq app=quarantined --overwrite
kubectl -n react label pod app=quarantined -l app=react2shell --overwrite
# pod/react2shell-6d4d4db59d-xwtxq labeled

# Confirm: Pod still running, now orphaned from the ReplicaSet
kubectl -n react get pods -o custom-columns='NAME:.metadata.name,APP:.metadata.labels.app,STATUS:.status.phase,NODE:.spec.nodeName'
# NAME                           APP           STATUS    NODE
# react2shell-6d4d4db59d-ht8jd   react2shell   Running   ip-10-0-47-8.ca-central-1.compute.internal
# react2shell-6d4d4db59d-xwtxq   quarantined   Running   ip-10-0-36-129.ca-central-1.compute.internal
```

---

### Isolate by network policy

```sh
# create netpol to block ingress, egress
kubectl -n react apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-isolate
  namespace: react
spec:
  podSelector:
    matchLabels:
      app: quarantined
  policyTypes: [Ingress, Egress]
EOF
# networkpolicy.networking.k8s.io/quarantine-isolate created

# confirm
kubectl -n react describe netpol quarantine-isolate
# Name:         quarantine-isolate
# Namespace:    react
# Created on:   2026-10-18 23:31:34 -0400 EDT
# Labels:       <none>
# Annotations:  <none>
# Spec:
#   PodSelector:     app=quarantined
#   Allowing ingress traffic:
#     <none> (Selected pods are isolated for ingress connectivity)
#   Allowing egress traffic:
#     <none> (Selected pods are isolated for egress connectivity)
#   Policy Types: Ingress, Egress

# test: egress blocked, timeout
kubectl -n react exec react2shell-6d4d4db59d-xwtxq -- timeout 5 curl -s -o /dev/null -w '%{http_code}\n' https://sts.ca-central-1.amazonaws.com
# command terminated with exit code 124

```

---

### Cordon inffected node

- cordon infected node
  - keep pod running
  - prevent new pod scheduled

```sh
# cordon
kubectl cordon ip-10-0-36-129.ca-central-1.compute.internal
# node/ip-10-0-36-129.ca-central-1.compute.internal cordoned

kubectl annotate node ip-10-0-36-129.ca-central-1.compute.internal cluster-autoscaler.kubernetes.io/scale-down-disabled=true
# node/ip-10-0-36-129.ca-central-1.compute.internal annotated

kubectl get node ip-10-0-36-129.ca-central-1.compute.internal
# NAME                                           STATUS                     ROLES    AGE     VERSION
# ip-10-0-36-129.ca-central-1.compute.internal   Ready,SchedulingDisabled   <none>   4h57m   v1.36.4-eks-b9510e3
```

---

## Incident Response Report

**Incident ID:** 2026-1019-01
**Reported by:** Platform Admin
**Date:** 2026-10-19
**Severity:** High — credential disclosure
**Status:** Contained, escalation required

---

### Summary

A routine `CloudTrail` inspection detected an irregular pattern of
`AssumeRoleWithWebIdentity` calls from the `react2shell` service account.
Investigation confirmed the access originated from a react pod to enumerate AWS Secrets Manager and read the RDS master
credential in plaintext. The compromised pod has been isolated. The disclosed credential remains valid.

---

### Timeline (UTC)

| Time     | Event                                                                                       |
| -------- | ------------------------------------------------------------------------------------------- |
| 00:10:36 | `AssumeRoleWithWebIdentity` → `ListSecrets` (enumeration)                                   |
| 00:10:45 | `AssumeRoleWithWebIdentity` → `GetSecretValue` on `react2shell-eks-insecure-rds-credential` |
| 00:14:21 | `GetSecretValue` on the same secret (second read)                                           |
| 00:14:24 | `ListSecrets` (re-enumeration)                                                              |
| 00:15:46 | Attacker activity ends; normal traffic resumes                                              |
| ~04:00   | Routine CloudTrail inspection; anomaly identified                                           |
| 04:31    | Pod quarantined, NetworkPolicy applied, evidence captured                                   |

Attack window: **00:10:36 – 00:14:25 UTC (3m49s)**

---

### Findings

- **Entry point:**
  - `POST /` to the Next.js application.
  - Command output was returned to the attacker through the error `digest` field.
- **Credential path:**
  - The pod's projected service-account token (`jti 39f92e76-…`) was used to assume `react2shell-eks-insecure-pod-irsa` four times, each session making exactly one API call — a per-request pattern no application produces.
- **Data disclosed:**
  - `react2shell-eks-insecure-rds-credential`, read twice.
  - Plaintext (`rds_admin` / password / host / port) appeared in pod logs, confirming the value reached the attacker.
- **Scope:**
  - `ListSecrets` succeeded, so the attacker also obtained the names, descriptions and tags of all secrets in the region.

---

### Containment actions taken

| Action                           | Result                                         |
| -------------------------------- | ---------------------------------------------- |
| Argo CD auto-sync disabled       | Manual changes persist                         |
| Pod relabelled `app=quarantined` | Removed from Service endpoints                 |
| Deny-all NetworkPolicy applied   | Egress to STS/Secrets Manager verified blocked |
| Evidence captured                | Logs, pod spec, SA token claims, events        |
| Node cordoned                    | Held pod protected from eviction               |

---

### Actions requires elevated permissions

| #   | Action                                                   | Rationale                                   |
| --- | -------------------------------------------------------- | ------------------------------------------- |
| 1   | Rotate `react2shell-eks-insecure-rds-credential`         | Plaintext disclosed; credential still valid |
| 2   | Revoke STS sessions issued before `2026-10-19T00:20:00Z` | Four sessions live until 01:14Z             |
| 3   | Review IAM and manifests misconfiguration                | Container access cloud secret               |
