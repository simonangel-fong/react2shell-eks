# Post 4: pipeline and monitoring slides

Source: [post04_pipeline.md](../post04_pipeline.md).

Perspective: DevSecOps engineer. Content is slide copy; captions provide concise narration. Optional evidence references distinguish configured workflows, recorded demonstrations, and future options.

## Slide 1

**Title:** React2Shell on Amazon EKS

**Content:**

One vulnerability. Four layers.

Attack. Detect. Harden.

**Caption:** None

## Slide 2

**Title:** A DevSecOps Engineer's Story

**Content:**

The environment is hardened. Changes keep coming.

How do we make security part of everyday delivery?

Check changes early. Monitor workloads after deployment.

A DevSecOps engineer integrates security into delivery and operations.

**Caption:** The DevSecOps engineer builds on the hardening work by integrating security checks into delivery workflows and runtime monitoring.

## Slide 3

**Title:** Shift Left: Security Checks in CI

**Content:**

| Workflow          | Checks                                           |
| ----------------- | ------------------------------------------------ |
| `ci-code.yml`     | Dependencies, exposed secrets, and configuration |
| `ci-image.yml`    | Dockerfile, image vulnerabilities, and SBOM      |
| `ci-manifest.yml` | Kubernetes manifest configuration                |
| `ci-iac.yml`      | Terraform validation, configuration, and secrets |

**Caption:** Four workflows check application code, images, Kubernetes manifests, and Terraform, bringing security feedback into the development process.

## Slide 4

**Title:** Shift Left: Code Layer

**Content:**

Check dependencies, secrets, and configuration.

- Scan dependencies for known vulnerabilities.
- Scan for exposed secrets and supported misconfigurations.

**Evidence:** screenshot: `github_actions_ci_code.png`.

**Caption:** The code workflow checks dependencies, exposed secrets, and configuration, giving developers early feedback on known issues.

## Slide 5

**Title:** Shift Left: Code Layer

**Content:**

Build and scan the image before the publish stage.

- Check the Dockerfile for misconfigurations.
- Build and scan the image.
- Generate a CycloneDX software bill of materials (SBOM).
- Publish only after prior jobs pass, on pushes to `master`.

**Evidence:** [Recorded image workflow](../img/pipeline/github_actions_ci_image.png)

**Caption:** The image workflow checks the Dockerfile, scans the built image, and generates an SBOM before the publish stage.

## Slide 6

**Title:** Shift Left: Cluster and Container Layers

**Content:**

Check Kubernetes manifests.

- Scan `argocd/secure-apps` for misconfigurations.
- Upload a SARIF report for review.
- Gate `react.yaml` on HIGH or CRITICAL findings.

**Evidence:** screenshot: `github_actions_ci_manifest.png`.

**Caption:** The workflow reports findings across the secure manifests and applies a blocking HIGH or CRITICAL severity gate to the application manifest.

## Slide 7

**Title:** Shift Left: Cloud Layer

**Content:**

Check Terraform configuration.

- Check formatting and validate `infra/eks-secure`.
- Scan infrastructure configuration and exposed secrets.
- Apply HIGH and CRITICAL gates with configured exceptions.

**Evidence:** screenshot: `github_actions_ci_iac.png`.

**Caption:** Terraform changes receive formatting, validation, configuration, and secret checks against the workflow's configured severity levels and exceptions.

## Slide 8

**Title:** Monitoring: Visibility After Deployment

**Content:**

| AWS Service | Focus                                                          |
| ----------- | -------------------------------------------------------------- |
| CloudWatch  | What is failing or degrading?                                  |
| CloudTrail  | Who called which AWS API, when, and from where?                |
| GuardDuty   | What potential threats or unusual activity need investigation? |

**Caption:** CloudWatch tracks operational health, CloudTrail records AWS API activity, and GuardDuty highlights potential threats for investigation.

## Slide 9

**Title:** Monitoring: Sample GuardDuty Alert

**Content:**

Test the notification path with a sample finding.

- Generate a GuardDuty sample finding.
- Type: `CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed`.
- Recorded severity: `5.0`.
- The administrator receives an email notification.

**Evidence:**
[Recorded SNS email](../img/pipeline/guardduty_alert_email.png)

**Caption:** A sample finding tests the GuardDuty, EventBridge, and SNS notification path. The recorded email confirms delivery to the administrator.

## Slide 10

**Title:** Future Option: Policy as Code

**Content:**

Extend enforcement with Kyverno or OPA Gatekeeper.

- Reject privileged workloads.
- Restrict image registries.
- Require ownership labels.

**Caption:** Policy as code could enforce deployment rules for workload privileges, approved registries, and ownership labels.

## Slide 11

**Title:** Future Option: Centralized Secret Management

**Content:**

AWS Secrets Manager and External Secrets Operator (ESO)

- Keep secret values out of Git manifests.
- Synchronize selected values into Kubernetes Secrets.
- Retain least-privilege access to those Secrets.

**Caption:** ESO could synchronize centrally managed values into Kubernetes Secrets, keeping values out of Git while retaining access controls.

## Slide 12

**Title:** Future Options: Deeper Observability

**Content:**

- VPC Flow Logs: network traffic metadata.
- CloudWatch Logs Insights: queries over collected logs.
- Falco: runtime security detection.
- LGTM: logs, dashboards, traces, and metrics.

**Caption:** Network logs, runtime detection, and broader observability could extend visibility.

## Slide 13

**Title:** Future Option: AIOps

**Content:**

Potential uses for AI in operations:

- Analyze security signals at scale.
- Correlate alerts and reduce noise.
- Support incident investigation and response automation.

**Caption:** AIOps could help correlate signals, prioritize alerts, and support response automation as monitoring grows.

## Slide 14 Attacker perspective

**Title:** One Vulnerability. Four Layers. Four Perspectives.

**Content:**

**Evidence:**
docs\img\diagram\summary.drawio.png

**Caption:** The attacker exploits React2Shell, reads container and cluster secrets, accesses the internal API, and retrieves a cloud secret.

## Slide 15 Platform admin perspective

**Title:** One Vulnerability. Four Layers. Four Perspectives.

**Content:**

**Evidence:**
docs\img\diagram\summary.drawio.png

**Caption:** The administrator traces AWS activity to the pod, preserves evidence, and quarantines the compromised workload.

## Slide 16 Security specialist perspective

**Title:** One Vulnerability. Four Layers. Four Perspectives.

**Content:**

**Evidence:**
docs\img\diagram\summary.drawio.png

**Caption:** The specialist patches the app and restricts container privileges, Kubernetes access, network traffic, and AWS permissions.

## Slide 17 DevSecOps engineer perspective

**Title:** One Vulnerability. Four Layers. Four Perspectives.

**Content:**

**Evidence:**
docs\img\diagram\summary.drawio.png

**Caption:** The DevSecOps engineer automates checks across all four layers and routes runtime security findings to the administrator.
