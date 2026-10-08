# reat2shell: harden codes

[Back](../README.md)

- [reat2shell: harden codes](#reat2shell-harden-codes)
  - [harden codes](#harden-codes)
  - [Steps](#steps)
  - [React fix](#react-fix)
  - [Dockerfile fix](#dockerfile-fix)
  - [Verify](#verify)

---

## harden codes

targets:

- react codes — patch the CVE (unauthenticated RCE in React Server Components)
- Dockerfile — minimal, non-root, no vulnerable build tooling in the runtime

---

## Steps

| #   | Steps          | Milestone                                        |
| --- | -------------- | ------------------------------------------------ |
| 1   | React fix      | exploit returns 404; `npm audit` clean           |
| 2   | Dockerfile fix | non-root, slim image; image scan passes the gate |

---

## React fix

- existing vulnerable app

```sh
# init next.js
mkdir ./app/react2shell-secure
npx create-next-app@latest ./app/react2shell-secure --js --app --src-dir --no-tailwind --no-eslint

# existing vulnerable version
npm install --prefix ./app/react2shell-secure next@15.2.2
```

- bump `next` to a patched 15.2 release; clear transitive deps.

```sh
cd app/react2shell-secure
# bump to 15.2.9
npm install next@15.2.9
# scans and installs updates
npm audit fix
npm install
npm audit
# found 0 vulnerabilities
```

---

## Dockerfile fix

`app/Dockerfile.secure` — best practices vs the insecure image:

- **multi-stage** (deps → build → runtime): build cache / dev deps never ship.
- **`output: standalone`** in `next.config.mjs`: trimmed self-contained server.
- **distroless base** (`gcr.io/distroless/nodejs20-debian12`): no shell, no npm, no apt → small OS attack surface.
- **non-root** user; runs `node server.js` (prod), not `npm run dev`.
- result: image ~245MB (was ~1.3GB).

```sh
docker build -f app/Dockerfile.secure -t react2shell:secure app
```

---

## Verify

```sh
# runs as non-root
docker run --rm --entrypoint sh react2shell:secure -c id 2>/dev/null || \
  echo "no shell (distroless) — check via k8s runtime instead"

# exploit fails (was: uid=0(root))
docker run --rm -d --name r2s -p 3100:3000 react2shell:secure
python scripts/rce.py http://localhost:3100 id
# status code: 404   /   executable response: (empty)
docker rm -f r2s

# image scan gate passes (app deps clean; base-image CVEs tracked in app/.trivyignore)
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed \
  --ignorefile app/.trivyignore --exit-code 1 react2shell:secure
# echo $?  -> 0
```
