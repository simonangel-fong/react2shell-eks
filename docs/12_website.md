# react2shell: Project Websites

[Back](../README.md)

- [react2shell: Project Websites](#react2shell-project-websites)
  - [Overview](#overview)
  - [Steps](#steps)
  - [Website design](#website-design)
  - [IaC](#iac)
  - [CI/CD pipelines](#cicd-pipelines)

---

## Overview

- Goal: create projet website
- file and stack:
  - infra/project: terraform
  - website/:
  - cicd: github actions automate terraform deployment

---

file

```
infra/
  project/
website/
```

---

## Steps

| #   | Step                   |
| --- | ---------------------- |
| 1   | Create project website |
| 2   | Create infra website   |
| 3   | CI/CD pipeline         |

---

## Website design

- stack: react 19 + vite + tailwind v4 (static build, no SSR)

- Design system
  - use tailwind built-ins; only customize what tailwind has no built-in for
  - palette: `slate` ground/text, `rose` for attack, `sky` for defense
  - `Inter` for prose, `JetBrains Mono` for technical terms
  - section container `max-w-6xl`; prose and figures share `max-w-4xl`

- Layout
  - Navbar: icon + wordmark, anchors, GitHub button, menu on mobile
  - Hero: full-bleed photo, copy left
  - Security and Business Challenge: pull-quote, four layers, four perspectives
  - Attack / Respond / Harden / Integrate: text + figure + demo recording
  - videos use native controls; no autoplay, audio left at the viewer's volume
  - Footer:

```sh
# local dev
npm --prefix website install
npm --prefix website run dev
```

---

## IaC

- stack: `infra/project` (terraform) — website hosting only
- domain: `react2shell-eks.arguswatcher.net`

| #   | Layer       | Service           | Description                                                   |
| --- | ----------- | ----------------- | ------------------------------------------------------------- |
| 1   | storage     | S3                | private origin bucket; versioned, encrypted, no public access |
| 2   | access      | S3 bucket policy  | `s3:GetObject` to the CloudFront service principal only       |
| 3   | cdn         | CloudFront        | public entry point; TLS, HTTP->HTTPS, `index.html` as root    |
| 4   | cdn access  | CloudFront OAC    | SigV4 origin access control, scoped to this distribution      |
| 5   | certificate | ACM (us-east-1)   | existing `*.arguswatcher.net`, looked up by `data` source     |
| 6   | dns         | Cloudflare        | `CNAME` to the distribution, DNS-only (grey cloud)            |
| 7   | ci identity | IAM OIDC provider | existing account-wide provider, looked up by `data` source    |
| 8   | ci role     | IAM role          | s3 sync on the site bucket + `CreateInvalidation`             |

- Notes
  - ACM must live in `us-east-1` for CloudFront, whatever region the stack uses.
  - OIDC trust uses GitHub's immutable subject format (default from 2026-07-15):
    `repo:OWNER@OWNER-ID/REPO@REPO-ID:ref:refs/heads/BRANCH`.
  - Only one OIDC provider per URL is allowed per account, so the GitHub one is
    shared with other stacks: this stack reads it and never creates or deletes it.
  - Cache split: `/assets/*` is content-hashed by vite and cached hard;
    everything else, `index.html` included, uses short TTLs so a deploy shows up.

```sh
# init
terraform -chdir=infra/project init -backend-config=backend.tfvars

terraform -chdir=infra/project fmt && terraform -chdir=infra/project validate
terraform -chdir=infra/project plan

terraform -chdir=infra/project apply -auto-approve
terraform -chdir=infra/project output
```

- publish website

```sh
BUCKET=$(terraform -chdir=infra/project output -raw site_bucket)
DIST=$(terraform -chdir=infra/project output -raw site_cloudfront_distribution_id)

# build
# videos default to /videos on the same origin; VITE_VIDEO_BASE_URL overrides it
npm --prefix website run build

# sync to s3; keep videos/, which is not part of the build output
aws s3 sync website/dist/ "s3://${BUCKET}/" --delete --exclude "videos/*"

# upload videos (once; they rarely change)
aws s3 sync docs/video/post "s3://${BUCKET}/videos/" --exclude "*" --include "*.mp4" --content-type "video/mp4" --cache-control "public,max-age=31536000,immutable"

# invalidate the cdn cache
aws cloudfront create-invalidation --distribution-id "${DIST}" --paths "/*"

# clean up
terraform -chdir=infra/project destroy -auto-approve
```

---

## CI/CD pipelines

| #   | Workflow                 | Trigger                         | Jobs                                     |
| --- | ------------------------ | ------------------------------- | ---------------------------------------- |
| 1   | `cd-website.yml`         | PR / push to master / manual    | website -> terraform -> apply -> publish |
| 2   | `cd-website-destroy.yml` | manual only, typed confirmation | destroy                                  |

- `cd-website.yml`

| Job         | Runs on       | Steps                                                         |
| ----------- | ------------- | ------------------------------------------------------------- |
| `website`   | every trigger | npm ci, build, trivy vuln+secret gate, upload `dist` artifact |
| `terraform` | every trigger | fmt, validate, trivy config SARIF + gate, secret gate         |
| `apply`     | master only   | OIDC -> apply role, terraform apply                           |
| `publish`   | after apply   | OIDC -> deploy role, s3 sync, cloudfront invalidation         |

- Notes
  - Two OIDC roles: `-github-apply` (terraform, master branch only) and
    `-github-deploy` (s3 sync + invalidation). The publish job never holds
    IAM write permissions.
  - `publish` downloads the artifact `website` built, so the bundle that was
    scanned is the one that ships.
  - Cache split on upload: hashed assets `immutable`, `index.html` `no-cache`.
  - PRs run the checks only; nothing touches AWS.
  - `infra/project/.trivyignore` records the two accepted findings (AWS-0132
    SSE-S3 over a CMK, AWS-0011 no WAF) with the reasoning for each.

- One-time setup

```sh
# repository variables
gh variable set AWS_REGION --body "ca-central-1"
gh variable set SITE_BUCKET --body "$(terraform -chdir=infra/project output -raw site_bucket)"
gh variable set CLOUDFRONT_DISTRIBUTION_ID --body "$(terraform -chdir=infra/project output -raw site_cloudfront_distribution_id)"
gh variable set AWS_ROLE_ARN_APPLY --body "$(terraform -chdir=infra/project output -raw github_apply_role_arn)"
gh variable set AWS_ROLE_ARN_DEPLOY --body "$(terraform -chdir=infra/project output -raw github_deploy_role_arn)"
gh variable set TF_STATE_BUCKET --body "<tf_state_bucket>"
gh variable set TF_STATE_KEY --body "<tf_state_key>"

# secrets (prompts, so the value stays out of shell history)
gh secret set CLOUDFLARE_API_TOKEN
gh secret set CLOUDFLARE_ZONE_ID

gh variable list && gh secret list
```

- Run

```sh
# deploy
gh workflow run cd-website.yml --ref master

# destroy (confirmation is required)
gh workflow run cd-website-destroy.yml --ref master -f confirm=destroy

# watch
gh run list --workflow cd-website.yml --limit 5
gh run watch "$(gh run list --workflow cd-website.yml --limit 1 --json databaseId --jq '.[0].databaseId')"

# inspect a failed gate
gh run view --log-failed
```
