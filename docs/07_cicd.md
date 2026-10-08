# reat2shell: CI/CD

[Back](../README.md)

- [reat2shell: CI/CD](#reat2shell-cicd)
  - [Overview](#overview)
  - [Branch Strategy](#branch-strategy)
  - [Step](#step)
  - [build-image](#build-image)
  - [lint-manifest](#lint-manifest)

---

## Overview

Shift security left: block insecure images and manifests in the PR, before merge.

- `build-image` — build, test, scan the container image; push only if clean.
- `lint-manifest` — scan k8s manifests for misconfig and policy violations.

---

## Branch Strategy

- work on a feature branch → open PR to `master`.
- both workflows run on the PR as **required status checks**.
- branch protection blocks the merge if any check fails → insecure change rejected.
- `master` is the deploy source; only reviewed, scanned changes land there.

---

## Step

| #   | Step          | Trigger                     | Milestone                          |
| --- | ------------- | --------------------------- | ---------------------------------- |
| 1   | build-image   | pull_request, push `app/**` | vulnerable image fails the scan    |
| 2   | lint-manifest | pull_request `argocd/**`    | vulnerable manifest fails the scan |

Common to both:

- **concurrency**: `${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true`.
- **cache**: npm keyed on `package-lock.json`; Docker layers via Buildx `type=gha`.
- **secrets**: registry creds from GitHub secrets (never hardcoded).

---

## build-image

- jobs/steps:
  - checkout
  - build app → unit test
  - build image (Buildx, gha cache)
  - **Trivy image scan** — fail on `HIGH,CRITICAL` (`--exit-code 1`)
  - push to registry only if the scan passes; tag with the commit SHA

```sh
# test locally / observe the run
gh workflow run build-image.yml
gh run watch
```

---

## lint-manifest

- scans manifests, not images.
- jobs/steps:
  - checkout
  - **Kyverno CLI** (`kyverno apply`) — fail if a manifest violates the image policy
  - **Checkov / Trivy config** — generic k8s misconfig (privileged, no limits, etc.)
  - fail the job on any violation → PR blocked

```sh
gh workflow run lint-manifest.yml
gh run watch
```

---

```sh
gh secret set DOCKERHUB_USERNAME --body ""
gh secret set DOCKERHUB_TOKEN --body ""


git checkout -b ci/build-image
git add .github/workflows/build-image.yml docs/07_cicd.md
git commit -m "ci: build-image workflow (build, test, trivy scan, push on master)"
git push -u origin ci/build-image
gh pr create --fill --base master
gh pr checks --watch        # see build-image run; Trivy should fail on the vulnerable image

```