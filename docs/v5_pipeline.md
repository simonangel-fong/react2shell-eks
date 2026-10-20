# reat2shell: Shift left and Shift right

[Back](../README.md)

- [reat2shell: Shift left and Shift right](#reat2shell-shift-left-and-shift-right)
  - [Overview](#overview)
  - [Shift left with CI/CD pipeline](#shift-left-with-cicd-pipeline)
  - [Monitoring: CloudWatch + CloudTrail + GuardDuty](#monitoring-cloudwatch--cloudtrail--guardduty)
  - [Advanced](#advanced)
    - [Policy as code: keyverno](#policy-as-code-keyverno)
    - [Sensitive data: ESO + secretmanager](#sensitive-data-eso--secretmanager)
    - [AWS Observability: VPC flow logs + Cloudwatch insight](#aws-observability-vpc-flow-logs--cloudwatch-insight)
    - [Provider-agnostic: falco + LGTM](#provider-agnostic-falco--lgtm)

---

## Overview

- Perspective: Cluster security specialist
- Goal: show how to integrate security pratices into SDLC
- Environment:
  - infra: eks-secure
  - manifests: insecure-apps
- Url: `http://react2shell.arguswatcher.net:3000`

- Secure Pipeline;
  - Shift left: static, supply chain
  - monitoring: GuardDuty
  - advanced:
    - Policy as code: keyverno
    - Sensitive data: ESO + secretmanager
    - Observability: VPC flow logs + Cloudwatch insight
    - provider-agnostic: falco + LGTM

---

## Shift left with CI/CD pipeline

| Security risk                  | Layers              | Solution   |
| ------------------------------ | ------------------- | ---------- |
| SAST                           | code                | trivy scan |
| image                          | code                | trivy scan |
| Software Supply Chain Security | code                | trivy SBOM |
| k8s manifest                   | container & cluster | trivy scan |
| trraform codes                 | cloud               | trivy scan |

| GitHub workflow   | Security risk                       | Trigger paths                       | Gate                                          |
| ----------------- | ----------------------------------- | ----------------------------------- | --------------------------------------------- |
| `ci-code.yml`     | SAST + secrets; dependency CVEs     | `app/react2shell-secure/**`         | HIGH/CRITICAL                                 |
| `ci-image.yml`    | image; SBOM + SLSA provenance       | `app/Dockerfile.secure`, app source | HIGH/CRITICAL; push only after scan           |
| `ci-manifest.yml` | k8s manifest misconfig;             | `argocd/secure-apps/react.yaml`     | HIGH/CRITICAL or policy violation             |
| `ci-iac.yml`      | Terraform cloud misconfig + secrets | `infra/**`                          | gate `eks-secure`; report-only `eks-insecure` |

- example

```sh
# trigger workflows using gh cli
gh workflow run ci-code.yml --ref secure
gh workflow run ci-image.yml --ref secure

# watch the most recent run
gh run watch "$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')"

# inspect a failed gate
gh run view --log-failed
```

![](github_action_screenshot)

---

## Monitoring: CloudWatch + CloudTrail + GuardDuty

- ## `GuardDuty`:

---

## Advanced

### Policy as code: keyverno

### Sensitive data: ESO + secretmanager

### AWS Observability: VPC flow logs + Cloudwatch insight

### Provider-agnostic: falco + LGTM
