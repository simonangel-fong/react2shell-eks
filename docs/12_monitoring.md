# reat2shell: cloud monitoring

[Back](../README.md)

- [reat2shell: cloud monitoring](#reat2shell-cloud-monitoring)
  - [Goal](#goal)
  - [Why AWS-native](#why-aws-native)
  - [Strategy](#strategy)
  - [Incident Arc](#incident-arc)

---

## Goal

Detect the Phase 10 cloud breach. The platform team is unaware until an alert
comes, then traces it back and hardens across the 4C layers.

- Scope: AWS-native detection. Details in the next step.

---

## Why AWS-native

The breach spans **two telemetry planes**:

```txt
RCE in pod ──────────────┐  (1) Kubernetes plane  → Falco / Loki (phase 4)
pod assumes IRSA role    │
  └─▶ get-secret-value ──┘  (2) AWS API plane      → CloudTrail / GuardDuty
```

Falco sees the in-cluster RCE. But `AssumeRoleWithWebIdentity` +
`GetSecretValue` leave the cluster and hit the AWS API — **invisible to
anything inside k8s**. That is why cloud-native monitoring is required.

---

## Strategy

Two detectors, one Slack alert.

| #   | Component       | Role                                                       | Note                     |
| --- | --------------- | ---------------------------------------------------------- | ------------------------ |
| 1   | CloudTrail      | records every AWS API call (system of record)              | forensic log for triage  |
| 2   | CloudWatch      | metric filter on `GetSecretValue` → alarm → SNS → Slack    | **demo trigger** (~1min) |
| 3   | GuardDuty (EKS) | managed threat detection → EventBridge → SNS → Slack       | **prod answer**, no rules|
| 4   | EKS audit logs  | k8s API calls → CloudWatch; feeds GuardDuty EKS Protection | off by default; enable   |

- **CloudWatch alarm** = deterministic trigger for the recorded demo.
- **GuardDuty** = what production runs (ML/threat-intel, no hand-written rules).
- Reuses the Phase 4 pattern (→ Slack), on the AWS side.

---

## Incident Arc

Alert from AWS, containment walks back through the 4C layers.

| #   | Stage   | Where                | Action                                     |
| --- | ------- | -------------------- | ------------------------------------------ |
| 1   | Detect  | CloudWatch/GuardDuty | Slack alert: `GetSecretValue` on rds secret |
| 2   | Triage  | CloudTrail           | who (assumed role), from where (pod)       |
| 3   | Correlate | Falco / Loki       | RCE + outbound call at the same time       |
| 4   | Contain | 4C layers            | Cloud IAM → Cluster RBAC/NP → Container PSS → Code CVE/scan |

**Milestone:** cloud breach alert is sent to Slack; blast radius traced and
minimized.

> Cost: GuardDuty + CloudTrail data events bill per volume — enable for the
> demo, disable after.
