# reat2shell: Shift left and Shift right

[Back](../README.md)

- [reat2shell: Shift left and Shift right](#reat2shell-shift-left-and-shift-right)
  - [Overview](#overview)
    - [Shift left and monitoring](#shift-left-and-monitoring)
    - [Steps](#steps)
  - [Shift Left](#shift-left)
  - [Shift Right](#shift-right)

---

## Overview

- Perspective: Cluster security specialist
- Goal: show how to secure system via ci/cd and grovernance service
- Environment:
  - infra: eks-secure
  - manifests: insecure-apps
- Url: `http://react2shell.arguswatcher.net:3000`

### Shift left and monitoring

- Shift left in ci/cd:
  - react test and scan
  - manifest scan
  - terraform scan
- GuardDuty
  - detect and alert

---

### Steps

| #   | Steps            | Layers    | Env                                  | Milestone                           |
| --- | ---------------- | --------- | ------------------------------------ | ----------------------------------- |
| 0   | Shift left       | cloud     | eks-secure + insecure-apps-cloud     | secure RDS secret                   |
| 1   | Shift right      | cluster   | eks-secure + insecure-apps-cluster   | secure cluster secret, internal api |
| 2   | Harden container | container | eks-secure + insecure-apps-container | secure sa token, apiserver, ESO     |
| 3   | Harden code      | code      | eks-secure + secure-apps             | disable exploit                     |

---

## Shift Left

- `Shift Left`
  - Moving security testing and checks earlier in the software development lifecycle (SDLC), toward the left side of the timeline (planning, design, and coding).
  - Goal: Catch and fix vulnerabilities, weak code, and misconfigurations before the software is ever built or released.

```sh

```

---

## Shift Right

- `Shift Right`
  - Extending security and testing later into the timeline, toward the right side (live production and runtime environments).
  - Goal: Monitor real-world user behavior, track live performance, detect zero-day attacks, and respond to incidents as they happen.

```sh

```
