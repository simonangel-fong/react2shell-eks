# reat2shell: project video

[Back](../README.md)

- [reat2shell: project video](#reat2shell-project-video)
  - [Goal](#goal)
  - [Series Spine](#series-spine)
  - [Posts \& Video \& document](#posts--video--document)

---

## Goal

A 5-part series: portfolio proof + LinkedIn activity while applying.

- p0 certification(hook)
- p1 attack
- p2 incident response
- p3 harden
- p4 integrate with business process

post:

- p0 and p1, same day, keep the hook
- p2 ~ p5, 1 video / 3days

**Batch-produce all 5 first**, then drip-release.

---

## Series Spine

- Same breach, same CVE, same cluster — seen from different perspectives.
  - Hacker, to steal sensitive data
  - Platform admin, to respond the incident
  - cluster security specialist, to harden the system
  - devsecops, to integrate security practices with business processes

- The **4C** model:
  - Cloud / Cluster / Container / Code
  - across 4 persona
  - direction flips with the persona:

```txt
p2 Attacker — climbs in:        code/container (RCE, token) → cluster (probe RBAC) -> cloud (RDS secret)
p3 Admin — trace, containment:  cloud → cluster → container (containment)
p4 Security — hardens:          cloud → cluster → container → code  (close the doors)
p5 devsecops — integrate:       cloud(terraform), cluster&container(manifests,POA,ESO), code (SAST)
```

---

## Posts & Video & document

- posts

| #   | Goal                                | Content                     | reference |
| --- | ----------------------------------- | --------------------------- | --------- |
| 0   | show cert, project hook             | text+images(cert+pass rate) |           |
| 1   | show how attacker used react2shell  | text(short)+video#1         |
| 2   | show how admin respond to incident  | text(short)+video#2         |
| 3   | show how to harden the system       | text(short)+video#3         |
| 4   | show how to integrate with business | text(short)+video#4         |

- video

| #   | Perspective         | Length | Content                                                 |
| --- | ------------------- | ------ | ------------------------------------------------------- |
| 1   | Hacker              | 4~5m   | React2Shell RCE → token → IRSA → RDS password           |
| 2   | Admin               | 4~5m   | CloudTrail -> pod logs -> containment -> report         |
| 3   | Security specialist | 4~5m   | 4C hardening cloud→code                                 |
| 4   | Devsecops           | 4~5m   | shift-left CI/CD; GuardDuty monitoring; Advanced topics |
