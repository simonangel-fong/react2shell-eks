# react2shell: Project Websites

[Back](../README.md)

- [react2shell: Project Websites](#react2shell-project-websites)
  - [Overview](#overview)
  - [Steps](#steps)
  - [Website design](#website-design)
  - [IaC](#iac)

---

## Overview

- Goal: create projet website
- file and stack:
  - infra/website: terraform
    - s3, acm, cloudfront, cloudflare
  - website/:
  - cicd: github actions automate terraform deployment

---

file

```
infra/
  website/
website/
```

---

## Steps

| #   | Step                   |
| --- | ---------------------- |
| 1   | Create project website |
| 2   | Create infra website   |

---

## Website design

- stack: react + tailwind

- Layout:
  - Navbar
  - hero
  - section: attacker
    - short text description
    - video
  - section: platform admin ir
    - short text description
    - video
  - section: hardening eks
    - short text description
    - video
  - section: devsecops
    - short text description
    - video

---

## IaC

```sh
# init
terraform -chdir=infra/website init -backend-config=backend.hcl
terraform -chdir=infra/website init -backend-config=backend.hcl -reconfigure
terraform -chdir=infra/website init -backend-config=backend.hcl -upgrade

terraform -chdir=infra/website fmt && terraform -chdir=infra/website validate
terraform -chdir=infra/website plan

terraform -chdir=infra/website apply -auto-approve
terraform -chdir=infra/website refresh
terraform -chdir=infra/website output

# clean up
terraform -chdir=infra/website destroy -auto-approve
```
