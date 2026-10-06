# AGENTS.md

## Metadata

- project purpose:
  - a personal k8s security lab around **CVE-2025-55182** ("React2Shell").
- Technologies:
  - react, kind, eks, argocd

---

## Repository layout

```txt
secure-aks/
  app/                react app source code
  argocd/             argocd, app-of-apps, k8s manifests
  kind/               kind cluster for local dev
  infra/
    project/          project-level terraform code
    eks/              eks terraform code
  docs/               documentation
  README
```

- Project development follows the documents in `docs/`
  - `PLAN.md`: general roadmap
  - `<num>_<doc_name>.md`: key phase's document

---

## Conventions

- NO `git commit`, `git push` UNLESS instructed
- NO `terraform apply`, `terraform destroy`
- Answer must be concise.
