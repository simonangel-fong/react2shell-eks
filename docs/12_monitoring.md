# react2shell: cloud monitoring

[Back](../README.md)

- [react2shell: cloud monitoring](#react2shell-cloud-monitoring)
  - [Overview](#overview)
  - [Log](#log)
    - [EKS audit log](#eks-audit-log)
    - [Netpol log](#netpol-log)
  - [Cloud Monitoring](#cloud-monitoring)
  - [Step](#step)
  - [EKS audit log](#eks-audit-log-1)
  - [Netpol log](#netpol-log-1)
  - [CloudTrail](#cloudtrail)
  - [GuardDuty](#guardduty)
  - [Alert to Slack](#alert-to-slack)
  - [Auto-response](#auto-response)
  - [Trace the breach](#trace-the-breach)

---

## Overview

- Following the workflow:
  - log -> detect -> alert -> trace -> debug

- Monitoring architecture

```txt
 log          EKS audit log  ─┐
              netpol log     ─┼─▶ CloudWatch
              CloudTrail     ─┴─▶ S3
                                   │
 detect       GuardDuty  ◀─────────┘   runtime (eBPF) + audit anomaly
                                   │
 alert        EventBridge ─▶ SNS ─▶ Slack ─▶ Lambda (auto-response)
```

---

## Log

### EKS audit log

- Enable log types:
  - `audit`: every k8s API call - who, verb, resource, namespace, IP.
  - `authenticator`: IAM -> k8s identity mapping; links the cloud/cluster planes.
- log group: `/aws/eks/<cluster>/cluster`
- stream `kube-apiserver-audit-*`

---

- confirm

```sh
# confirm enabled
aws eks describe-cluster --name react2shell-eks-secure \
  --query 'cluster.logging.clusterLogging[?enabled==`true`].types'

# replay: SA reads the cluster secret
python scripts/rce.py http://localhost:3000 "..."

# query: who read secrets
aws logs start-query \
  --log-group-name /aws/eks/react2shell-eks-secure/cluster \
  --query-string 'fields @timestamp, user.username, verb, objectRef.resource, objectRef.namespace, sourceIPs.0
    | filter objectRef.resource = "secrets" and verb in ["get","list"]'
```

---

### Netpol log

- VPC CNI addon:
  - `enablePolicyEventLogs` + `enableCloudWatchLogs`
- CNI role:
  - `logs:CreateLogStream`
  - `PutLogEvents`;
  - Cost: +1 vCPU per node
- node file:
  - `/var/log/aws-routed-eni/network-policy-agent.log`

---

- confirm

```sh
# replay: frontend reaches the backend api
python scripts/rce.py http://localhost:3000 "curl -sS -m 5 http://backend-api.backend/api/v1/users"

# query: verdict on the flow
aws logs start-query \
  --log-group-name /aws/eks/react2shell-eks-secure/cluster \
  --query-string 'fields @timestamp, `Src IP`, `Dest IP`, `Dest Port`, Verdict
    | filter Verdict = "DENY"'
```

- `ACCEPT` on frontend→backend = backend not isolated (missing NetworkPolicy).

---


## Cloud Monitoring

AWS-native monitoring — the managed equivalent of the Falco + Loki + Grafana
stack used on kind.

```txt
 log          EKS audit log  ─┐
              netpol log     ─┼─▶ CloudWatch
              CloudTrail     ─┴─▶ S3
                                   │
 detect       GuardDuty  ◀─────────┘   runtime (eBPF) + audit anomaly
                                   │
 alert        EventBridge ─▶ SNS ─▶ Slack ─▶ Lambda (auto-response)
```

- Enable the logs before the detector — GuardDuty EKS findings are derived from
  the EKS audit log.
- Netpol logs, not VPC Flow Logs, for pod↔pod: Flow Logs carry no pod identity
  and miss same-node traffic.

---

## Step

Enable one source, replay the breach, confirm it shows up.

| #   | Step             | Replay                    | Milestone                                 |
| --- | ---------------- | ------------------------- | ----------------------------------------- |
| 1   | EKS audit log    | SA reads `backend` secret | secret access found in Logs Insights      |
| 2   | Netpol log       | react pod → backend api   | frontend→backend verdict logged           |
| 3   | CloudTrail       | pod assumes IRSA role     | `AssumeRoleWithWebIdentity` in trail      |
| 4   | GuardDuty        | re-run the exploit        | runtime + audit findings raised           |
| 5   | Alert to Slack   | sample finding            | Slack shows critical alert                |
| 6   | Auto-response    | re-run the exploit        | role session revoked, pod isolated        |
| 7   | Trace the breach | full exploit chain        | compromised layer and vulnerability named |

---

## EKS audit log

- `infra/eks-secure/11_eks.tf`: `enabled_log_types = ["audit", "authenticator"]`
- log group `/aws/eks/<cluster>/cluster`, stream `kube-apiserver-audit-*`

```sh
# confirm enabled
aws eks describe-cluster --name react2shell-eks-secure \
  --query 'cluster.logging.clusterLogging[?enabled==`true`].types'

# replay: SA reads the cluster secret
python scripts/rce.py http://localhost:3000 "..."

# query: who read secrets
aws logs start-query \
  --log-group-name /aws/eks/react2shell-eks-secure/cluster \
  --query-string 'fields @timestamp, user.username, verb, objectRef.resource, objectRef.namespace, sourceIPs.0
    | filter objectRef.resource = "secrets" and verb in ["get","list"]'
```

---

## Netpol log

- VPC CNI addon config: `enablePolicyEventLogs` + `enableCloudWatchLogs`
- needs `logs:CreateLogStream`/`PutLogEvents` on the CNI role; +1 vCPU per node
- node file `/var/log/aws-routed-eni/network-policy-agent.log`

```sh
# replay: frontend reaches the backend api
python scripts/rce.py http://localhost:3000 "curl -sS -m 5 http://backend-api.backend/api/v1/users"

# query: verdict on the flow
aws logs start-query \
  --log-group-name /aws/eks/react2shell-eks-secure/cluster \
  --query-string 'fields @timestamp, `Src IP`, `Dest IP`, `Dest Port`, Verdict
    | filter Verdict = "DENY"'
```

- `ACCEPT` on frontend→backend = backend not isolated (missing NetworkPolicy).

---

## CloudTrail

- `infra/eks-secure/15_cloudtrail.tf`: multi-region trail to S3
- management events only; `GetSecretValue` is a **data event** and needs a data
  event selector on `AWS::SecretsManager::Secret`

```sh
# replay: pod assumes the IRSA role and reads the secret
python scripts/rce.py http://localhost:3000 "aws secretsmanager get-secret-value --secret-id ..."

# confirm
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --query 'Events[].{time:EventTime,user:Username}'
```

---

## GuardDuty

- `infra/eks-secure/16_guardduty.tf`
- `aws_guardduty_detector` + `aws_guardduty_detector_feature`:
  - `EKS_AUDIT_LOGS`
  - `RUNTIME_MONITORING` with `EKS_ADDON_MANAGEMENT`
    (mutually exclusive with the older `EKS_RUNTIME_MONITORING`)

```sh
# confirm features + agent
aws guardduty get-detector --detector-id <id> --query 'features[].{n:name,s:status}'
kubectl -n amazon-guardduty get pods

# replay the exploit, then list findings
aws guardduty list-findings --detector-id <id> \
  --finding-criteria '{"Criterion":{"severity":{"Gte":4}}}'
```

Expected findings — generic, no rule naming our app or secret:

| Layer     | Finding                                                         | Severity |
| --------- | --------------------------------------------------------------- | -------- |
| Container | `Execution:Runtime/ReverseShell`                                | High     |
| Cluster   | `CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed` | Medium   |
| Cloud     | `CredentialAccess:IAMUser/AnomalousBehavior`                    | Medium   |
| All       | `AttackSequence:EKS/CompromisedCluster`                         | Critical |

- `AnomalousBehavior.*` needs ~7–14 days of baseline — may not fire on a new
  cluster. Runtime findings are signature-based and fire immediately.

---

## Alert to Slack

- `infra/eks-secure/17_alerting.tf`
- EventBridge rule: `source = aws.guardduty`, `severity >= 7` → SNS → Slack
- route on severity, not finding type

```sh
# test the path without a breach
aws guardduty create-sample-findings --detector-id <id> \
  --finding-types CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed
```

- Demo fallback: if GuardDuty has no baseline yet, add an EventBridge rule on
  `AssumeRoleWithWebIdentity` / `ListSecrets` to guarantee an alert.
  Use EventBridge, not a CloudWatch metric filter — CloudTrail → CloudWatch
  delivery lags 5–15 min.

---

## Auto-response

- Lambda on the same EventBridge rule:
  - revoke the IRSA role sessions (`AWSRevokeOlderSessions`)
  - apply a deny-all NetworkPolicy to the pod label
- Secrets Manager rotation caps the lifetime of a stolen credential.

---

## Trace the breach

Replay the full chain; each signal names the layer that failed.

| Signal                                        | Layer     | Vulnerability                 |
| --------------------------------------------- | --------- | ----------------------------- |
| image scan: CVE-2025-55182                    | Code      | unpatched dependency          |
| `Execution:Runtime/ReverseShell`              | Container | no PSS, root, writable rootfs |
| netpol log: `ACCEPT` frontend→backend         | Cluster   | backend not isolated          |
| audit: `verb=get resource=secrets ns=backend` | Cluster   | RBAC grants SA secret access  |
| CloudTrail: `AssumeRoleWithWebIdentity`       | Cloud     | IRSA role bound to a web pod  |
| CloudTrail: `GetSecretValue`                  | Cloud     | IAM policy `Action:*`         |
