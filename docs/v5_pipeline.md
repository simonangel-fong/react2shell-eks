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

| GitHub workflow   | Security risk                                                           | Trigger paths                                 | Gate                                          |
| ----------------- | ----------------------------------------------------------------------- | --------------------------------------------- | --------------------------------------------- |
| `ci-code.yml`     | SAST + secrets in source; dependency CVEs (incl. CVE-2025-55182)        | `app/react2shell-secure/**`                   | fail on HIGH/CRITICAL                         |
| `ci-image.yml`    | Dockerfile misconfig; image CVEs; supply chain (SBOM + SLSA provenance) | `app/Dockerfile.secure`, app source           | fail on HIGH/CRITICAL; push only after scan   |
| `ci-manifest.yml` | k8s manifest misconfig; Kyverno admission policy shifted left           | `argocd/secure-apps/**`, `argocd/platform/**` | fail on HIGH/CRITICAL or policy violation     |
| `ci-iac.yml`      | Terraform cloud misconfig; hardcoded secrets                            | `infra/**`                                    | gate `eks-secure`; report-only `eks-insecure` |

Each workflow maps one row of the risk table above to one layer, so a failing
check names the layer that broke.

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
