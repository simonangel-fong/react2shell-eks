# reat2shell: project video

[Back](../README.md)

- [reat2shell: project video](#reat2shell-project-video)
  - [Goal](#goal)
  - [Series Spine](#series-spine)
  - [Videos](#videos)
  - [Production Notes](#production-notes)
  - [Storyboard](#storyboard)
    - [Hack](#hack)
    - [Routine Inspection](#routine-inspection)
    - [System Hardening](#system-hardening)
    - [Shift left and monitoring](#shift-left-and-monitoring)

---

## Goal

A 4-part series: portfolio proof + weekly LinkedIn activity while applying.
Attack first (the hook), defense after (the credibility).

- 1 video / week. **Batch-produce all 4 first**, then drip-release.

---

## Series Spine

Same breach, same CVE, same cluster — seen from different seats. The **4C**
(Cloud / Cluster / Container / Code) is the axis the story travels along, and
the direction flips with the persona:

```txt
V2 Attacker  — climbs in:     code/container (RCE, token) → cluster (probe RBAC)
V3 Operator  — traces back:   cloud → cluster → container → code  (find root cause)
V4 Operator  — hardens:       cloud → cluster → container → code  (close the doors)
```

Open each video naming the spine: _"same breach you saw me run — different seat."_

---

## Videos

| #   | Persona  | Beat              | Content                                                                                                 | Medium                       | Length |
| --- | -------- | ----------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------- | ------ |
| 1   | Learner  | Hook              | Failed CKS on execution (exam-UI muscle memory), retook, passed → cert ≠ capability → "so I built this" | Talking head                 | ~90s   |
| 2   | Red team | Attack            | React2Shell RCE → token → IRSA pivot → SigV4 → 🪙 DB password; probe cluster RBAC (hits the wall)       | **Live terminal**            | 4–5m   |
| 3   | Operator | Detect & identify | Alert fires → CloudTrail triage → Falco correlation → trace root cause cloud→code                       | Screen + narration           | 4–5m   |
| 4   | Operator | Harden & prevent  | 4C hardening cloud→code + shift-left CI/CD rejecting the insecure push                                  | **Conceptual / screenshots** | 4–5m   |

- **V1** — drop the word "loser"; let the specific failure (e.g. `ctrl+shift+c`
  vs `ctrl+c`, a solvable question left empty on time) carry the humility.
- **V2** — live screen capture = proof, not slides. Pace like an attacker. Land
  the `aws: not found → Node SigV4 → secret` sequence.
- **V3** — the senior beat: Falco saw the RCE, but the secret theft was on the
  **AWS API plane** — invisible to the cluster. Two planes correlate here.
- **V4** — conceptual; 4C already shown in V2/V3. **Name** the senior concepts
  (scoped IRSA, PSS, shift-left) via screenshots; keep deep-dives for interview.

---

## Production Notes

| Item    | Note                                                                                                            |
| ------- | --------------------------------------------------------------------------------------------------------------- |
| Titles  | Sell the stakes, not the persona (e.g. _"I stole a DB password with one request"_)                              |
| Order   | Attacker (V2) is the funnel → defense (V3/V4) retains                                                           |
| Honesty | V2's cluster beat = attacker **fails** against the hardening — do not stage a breach the cluster already blocks |
| Index   | Pin a series index linking all 4 + the repo (4C docs)                                                           |
| Budget  | ~1h edit per finished minute; ~18m total is a real project                                                      |

---

## Storyboard

### Hack

Actor: Hacker
Plot: show how hacker exploit
Environment: eks-insecure + insecure-apps

- Code level exploit:
  - scan dns and try id
- Container level exploit:
  - access container secret
  - access sa token
- Cluster level exploit:
  - request internal api
  - access cluster secret
- Cloud level exploit
  - RDS secret

---

### Routine Inspection

Actor: k8s admin
Plot: show how admin identify and confirm blast radius
Environment: eks-insecure + insecure-apps

- Cloud level:
  - find unknown access to the secret
    - `2026-10-17T18:05:14.216Z	system:serviceaccount:react:react2shell	list 10.0.35.58`
- confirm blast radius:observed damage vs possible damage
  - Cloud level: inspect IAM
    - cloudtrail log: rds secret
  - Cluster level:
    - inspect rbac
      - cluster secret
      - netpol log: access to internal api
    - netpol log
      - internal api
  - Container level:
    - container secret
    - sa token

---

### System Hardening

Actor: k8s security specialist
Plot: show how to secure system

- cloud level
  - environment: eks-secure + insecure-apps-cloud
  - cannot access RDS secret
- cluster level：
  - environment: eks-secure + insecure-apps-cluster
  - cannot access cluster secret, internal api
- container level:
  - environment: eks-secure + insecure-apps-container
  - container secret still readable
  - not sa token
  - no apiserver access
- code level:
  - environment: eks-secure + secure-apps
  - cannot exploit

---

### Shift left and monitoring

Actor: k8s security specialist
Plot: show how to secure system via ci/cd and grovernance service

- Shift left in ci/cd:
  - react test and scan
  - manifest scan
  - terraform scan
- GuardDuty
  - detect and alert
