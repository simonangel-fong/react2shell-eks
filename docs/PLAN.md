# React2Shell to EKS

**Goal:** Prove security skill end-to-end on one real CVE — exploit it, detect it, harden it, then prove containment.

**CVE:** CVE-2025-55182 ("React2Shell") — unauthenticated RCE in React Server Components (CVSS 10.0), triggered by a single crafted POST.

## Repository layout

```txt
react2shell-eks/
  app/                react app source code
  argocd/             argocd, app-of-apps, k8s manifests
  kind/               kind cluster for local dev
  infra/
    eks-secure/       eks cluster with secure config
    eks-insecure/     eks cluster with insecure config
    website/          website
  docs/               documentation
  README
```

## Phases

| #   | Phase                | Description                                                | Milestone                                 | Progress |
| --- | -------------------- | ---------------------------------------------------------- | ----------------------------------------- | -------- |
| 1   | vulnerable app       | Develop Next.js web app with React2Shell-vulnerability     | Exploit React2Shell-vulnerability locally | Done     |
| 2   | local kind           | Create local kind cluster and k8s resources;               | A local kind cluster runs                 | Done     |
| 3   | local breach         | Exploit the app and retrieve crown jewels                  | Crown jewels get retrieves                | Done     |
| 4   | Detect               | Deploy grafana+loki; set alert; verify attack              | Alert is send to slack                    | Done     |
| 5   | Harden cluster       | Harden at cluster level                                    | Secure cluster level crown jewel          | Done     |
| 6   | Harden container     | Harden at pod/container level                              | Secure at pod/container level             | Done     |
| 7   | Harden code          | Harden at code/dockerfile level                            | Secure at code/dockerfile level           | Done     |
| 8   | shift left           | create github actions workflow                             | Insecure push get rejected                | Done     |
| 9   | Insecure EKS & breah | Create insecure AWS resources; retrieve cloud crown jewels | Cloud level crown jewels get retrieves    | Done     |
| 10  | Secure EKS           | Harden at cloud level                                      | Secure at cloud level                     | Done     |
| 11  | Cloud monitoring     | AWS-native detection: CloudTrail + GuardDuty → Slack       | Cloud breach alert is send to slack       | Done     |
| 12  | post 01              | show CKS + project hook                                    | post01                                    | Done     |
| 13  | post 02 & video 01   | show attack                                                | post02 & video01                          | Done     |
| 14  | post 03 & video 02   | show incident response                                     | post03 & video02                          | Done     |
| 15  | post 04 & video 03   | show hardening                                             | post04 & video03                          | Done     |
| 16  | post 05 & video 04   | show pipeline                                              | post05 & video04                          | Done     |
| 17  | project website      | Create project website                                     | Website online                            | Done     |

**Crown jewels (escalating blast radius)**

- **Container level**: Service account token
- **Cluster level**: DynamoDB secret
- **Cloud level**: RDS secret

**Hardening layers:**

- **Container level**: image patch, supply chain, privileged, security context
- **Cluster level**: imagepolicy(Kyverno), PSS, RBAC, NP
- **Cloud level**: IAM, security group, VPC...
