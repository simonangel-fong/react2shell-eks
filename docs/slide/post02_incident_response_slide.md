# Post 2: incident response slides

Source: [post02_incident_response.md](post02_incident_response.md).

Perspective: platform administrator. Content is slide copy; captions provide concise narration. Evidence references and excerpts support the slides.

## Slide 1

**Title:** React2Shell on Amazon EKS

**Content:**

One vulnerability. Four layers.

Attack. Detect. Harden.

**Caption:** The attack exposed a cloud secret. Now we follow the platform administrator's investigation and response.

## Slide 2

**Title:** An Administrator's Story

**Content:**

Scenario: hours after a React2Shell breach in an EKS cluster.

The platform administrator starts the scheduled routine review …

**Caption:** Hours after the attack, The platform administrator starts the scheduled routine review.

## Slide 3

**Title:** Routine Review: CloudTrail Sessions

**Content:**

Four recent sessions warrant investigation.

- Same workload identity.
- Event: `AssumeRoleWithWebIdentity`.
- Four sessions within four minutes.

**Evidence:** [CloudTrail event list](img/platform_admin/webid_event.png).

**Caption:** Four recent sessions share the same workload identity. The administrator checks whether this activity matches the application's expected behavior.

## Slide 4

**Title:** Routine Review: Workload Identity

**Content:**

The full event identifies the workload.

- IAM role: `react2shell-eks-insecure-pod-irsa`.
- Namespace: `react`.
- Service account: `react2shell`.

**Evidence:** [Full CloudTrail event](img/platform_admin/webid_event_full.png). Use the identity and role fields only.

**Caption:** The event identifies the service account, its namespace, and the IAM role it assumed.

## Slide 5

**Title:** Routine Review: Summary

**Content:**

- Unexpected AWS activity uses the `react2shell` service account identity.
- The source and accessed resources need investigation.

Next: trace the activity.

**Evidence:** [CloudTrail sessions](img/platform_admin/webid_event.png) and [identity details](post02_incident_response.md#routine-inspection).

**Caption:** Routine review reveals an unexpected activity that requires investigation. Next, the administrator traces the source and checks what each session accessed.

## Slide 6

**Title:** Investigation: Source IP

**Content:**

The source IP matches cluster egress.

- Source IP: `16.54.55.36`.
- Matches the EKS environment's NAT gateway.
- Workload evidence is still needed to identify the pod.

**Evidence:** [NAT gateway lookup](img/platform_admin/webid_ip_check.png).

**Caption:** The source IP matches the cluster's NAT gateway. This points to shared cluster egress, but does not identify a specific pod.

## Slide 7

**Title:** Investigation: Accessed Resources

**Content:**

Two reads of the same cloud secret.

2026-10-19 / UTC

| Time     | Action         | Result             |
| -------- | -------------- | ------------------ |
| 00:10:36 | ListSecrets    | Secret discovery   |
| 00:10:45 | GetSecretValue | Lab RDS credential |
| 00:14:21 | GetSecretValue | Same credential    |
| 00:14:25 | ListSecrets    | Secret discovery   |

**Evidence:** [Session activity lookup](img/platform_admin/webid_access_resources.png) and [complete recorded results](post02_incident_response.md#identify-resources-involved).

**Caption:** Session lookups reveal secret discovery and two reads of the same lab RDS credential within four minutes.

## Slide 8

**Title:** Investigation: Locate the Pod

**Content:**

- Find pods using service account `react2shell`.
- Matching pod: `react2shell-6d4d4db59d-xwtxq`.
- Compare its logs with the CloudTrail sessions.

**Evidence:** [Recorded pod lookup](post02_incident_response.md#cross-check-confirm-pod-log). Output excerpt:

```text
Pod:       react2shell-6d4d4db59d-xwtxq
Started:   2026-10-19T00:04:05Z
Restarts:  0
```

**Caption:** The administrator locates the pod using this service account, then checks its logs against the AWS activity.

## Slide 9

**Title:** Investigation: Pod Logs

**Content:**

Pod logs confirm secret exposure.

- Session key matches CloudTrail.
- Error digest contains the lab secret value.
- Timestamps align with `GetSecretValue`.

**Evidence:** [Timestamped pod logs](img/platform_admin/react_pod_logs02.png).

**Caption:** Matching session keys and timestamps connect the AWS activity to the pod. Its error output contains the lab secret value.

## Slide 10

**Title:** Investigation: Summary

**Content:**

The evidence confirms a breach.

- CloudTrail records successful secret access.
- Pod logs contain the matching session and secret output.

Next: preserve evidence and contain the pod.

**Evidence:** [CloudTrail activity](img/platform_admin/webid_access_resources.png) and [corroborating pod logs](img/platform_admin/react_pod_logs02.png).

**Caption:** CloudTrail and pod logs corroborate the breach. The administrator now preserves evidence and limits the compromised pod's access.

## Slide 11

**Title:** Containment: Pause GitOps Reconciliation

**Content:**

- Disable Argo CD auto-sync.

**Evidence:** [Argo CD auto-sync setting](img/platform_admin/containment_disable_argocd.png) and [Application hierarchy check](post02_incident_response.md#disable-argo-cd-auto-sync).

**Caption:** The administrator pauses automatic sync and checks the Application hierarchy so GitOps does not undo the containment changes.

## Slide 12

**Title:** Containment: Preserve Evidence

**Content:**

Capture evidence before disruptive changes.

- Timestamped pod logs.
- Pod specification and Kubernetes events.
- Decoded token claims for identity correlation.

**Evidence:** [Evidence collection commands and recorded result](post02_incident_response.md#collect-evidence).

```text
Evidence files: pod.log, pod.yaml, events.txt, token-decode.txt
Session-key entries in pod.log: 4
```

**Caption:** The administrator saves logs, workload details, events, and token claims while keeping the original pod available for investigation.

## Slide 13

**Title:** Containment: Network Quarantine

**Content:**

Keep the compromised pod running while limiting its access.

- Relabel it `app=quarantined` to remove the Service selector match.
- Apply a quarantine NetworkPolicy with no ingress or egress rules.

**Evidence:** [Recorded pod state](post02_incident_response.md#remove-the-pod-from-the-service) and [quarantine policy and connectivity test](post02_incident_response.md#isolate-by-network-policy).

```text
Original pod:     app=quarantined   Running
Replacement pod:  app=react2shell   Running
STS egress test:  exit code 124 (timeout)
```

**Caption:** Relabeling removes the Service selector match. The administrator applies the quarantine policy and confirms that the STS egress test times out.

## Slide 14

**Title:** Containment: Cordon the Hosting Node

**Content:**

- Mark the node unschedulable.
- Leave existing pods running for investigation.

**Evidence:** [Recorded cordon and autoscaler annotation](post02_incident_response.md#cordon-inffected-node). Node status:

```text
Ready,SchedulingDisabled
```

**Caption:** Cordoning prevents ordinary new scheduling on the hosting node.

## Slide 15

**Title:** Report and Escalation

**Content:**

Record the findings and escalate cloud credential cleanup.

- Rotate the disclosed credential.
- Revoke any still-active compromised sessions.
- Restrict the workload's IAM access.

**Evidence:** [Incident report](post02_incident_response.md#incident-response-report) and [pending actions requiring elevated permissions](post02_incident_response.md#actions-requires-elevated-permissions).

```text
Incident:  2026-1019-01
Severity:  High — credential disclosure
Status:    Pod quarantined; cloud cleanup pending
```

**Caption:** The report records the breach and containment actions. Cloud owners must address the exposed credential and any remaining session access.

## Slide 16

**Title:** Incident Response Summary

**Content:**

- CloudTrail identifies the workload and secret access.
- Pod logs connect the activity to the application.
- Evidence collection and quarantine support investigation and containment.
- Escalation assigns the remaining credential cleanup.

**Evidence:** [Incident findings](post02_incident_response.md#findings), [containment results](post02_incident_response.md#containment-actions-taken), and [pending cloud actions](post02_incident_response.md#actions-requires-elevated-permissions).

**Caption:** The administrator connects the evidence, quarantines the pod, and escalates credential cleanup. Permanent remediation still requires further work.

## Slide 17

**Title:** What Comes Next?

**Content:**

The pod is quarantined.

How does EKS cluster prevent the next breach?

To be continued: Hardening EKS

**Caption:** The administrator has contained the compromised pod and report the incident. Next, we switch to the security specialist’s perspective to harden the EKS.
