# Post 3: hardening slides

Source: [post03_hardening.md](post03_hardening.md).

Perspective: security specialist. Content is slide copy; captions provide concise narration. Evidence references describe recorded lab results.

## Slide 1

**Title:** React2Shell on Amazon EKS

**Content:**

One vulnerability. Four layers.

Attack. Detect. Harden.

**Caption:** None

## Slide 2

**Title:** A Security Specialist's Story

**Content:**

Containment limits the current incident. The underlying weaknesses still need remediation.

A security specialist begins hardening the environment...

**Caption:** The pod is quarantined, but the weaknesses remain. The security specialist now hardens each layer and tests the controls.

## Slide 3

**Content:**

- **Layer:** Cloud.
- **Issue:** The pod can read the lab RDS credential.
- **Cause:** An overly permissive pod IAM role.
- **Fix:** Remove the unnecessary role.

**Evidence:**
[Original broad IAM role](../infra/eks-insecure/13_irsa.tf)
[secure Terraform configuration](../infra/eks-secure/)
[documented cloud changes](post03_hardening.md#root-cause-analysis).

**Caption:** The application does not need this cloud access. The specialist removes the broad IAM role used in the attack.

## Slide 4

**Content:**

- **Layer:** Cloud.
- **Issue:** The pod receives an unnecessary AWS identity.
- **Cause:** The service account's IRSA role annotation.
- **Fix:** Remove the annotation.

**Evidence:**
[Service account manifest without the role annotation](../argocd/insecure-apps-cloud/react-rbac.yaml).

**Caption:** Removing the annotation stops new application pods from receiving the previous IRSA identity configuration.

## Slide 5

**Content:**

Attack replay: read cloud-wide secret

- IRSA environment variables are absent.
- The replay script cannot use the previous role-assumption path.

**Evidence:**
[Missing AWS identity variables](img/harden/cloud01.png)
[failed secret-listing attempt](img/harden/cloud02.png).

**Caption:** The app remains exploitable, but the replay script cannot find the IRSA identity it previously used to access cloud secrets.

## Slide 6

**Content:**

Cloud layer

- Remove unnecessary IAM permissions.
- Stop projecting the previous IRSA identity.
- Block the demonstrated cloud-secret access path.

Next: restrict access inside the cluster.

**Caption:** Cloud hardening blocks the demonstrated IRSA path. Next, the specialist restricts the workload's access inside the cluster.

## Slide 7

**Content:**

- **Layer:** Cluster.
- **Issue:** The workload can read secrets in the `internal` namespace.
- **Cause:** Overly broad RBAC permissions.
- **Fix:** Grant only the permissions the workload needs.

**Evidence:**
[Restricted service account manifest](../argocd/insecure-apps-cluster/react-rbac.yaml)
[documented RBAC changes](post03_hardening.md#rbac).

**Caption:** The specialist removes broad secret-read permissions, limiting the Kubernetes service account to the access this workload needs.

## Slide 8

**Content:**

Attack replay: read cluster-wide secret

- The cluster-wide secret request returns `403 Forbidden`.
- RBAC checks deny cluster-wide secret reads.

**Evidence:** [RBAC checks and rejected secret request](img/harden/cluster_rbac_secret.png).

**Caption:** Replaying the secret request now returns Forbidden. The service account no longer has broad access to cluster secrets.

## Slide 9

**Content:**

- **Layer:** Cluster.
- **Issue:** The compromised app can read internal API data.
- **Cause:** Missing network isolation.
- **Fix:** Use NetworkPolicies to allow only intended callers.

**Evidence:**
[Internal namespace NetworkPolicies](../argocd/insecure-apps-cluster/internal-netpol.yaml).

**Caption:** The specialist adds default-deny isolation and explicit access rules for the internal service.

## Slide 10

**Content:**

Attacke replays: Internal API

- The compromised app's request to the internal API times out.

**Evidence:**
[Network policies and internal API replay](img/harden/cluster_netpol_api.png).

**Caption:** After network isolation, the recorded request from the compromised application to the internal API times out.

## Slide 11

**Content:**

Cluster layer

- Cluster-wide secret listing is forbidden.
- The internal API request times out.

Next: harden the container itself.

**Caption:** Authorization rejects secret access, and the internal API request times out. Next, the specialist hardens the container itself.

## Slide 12

**Content:**

- **Layer:** Container.
- **Issue:** Root execution, unrestricted privilege escalation, and a readable Kubernetes token.
- **Cause:** Missing runtime security controls.
- **Fix:** Apply a restrictive security context and disable automatic token mounting.

**Evidence:**
[Pod and container security contexts](../argocd/insecure-apps-container/react.yaml)
[disabled token mounting](../argocd/insecure-apps-container/react-rbac.yaml).

**Caption:** The specialist limits process privileges, makes the root filesystem read-only, and disables automatic Kubernetes token mounting.

## Slide 13

**Content:**

Attack Replay: security context

- The standard Kubernetes service account token is absent.
- Commands run as a non-root user.
- Writes to the root filesystem fail.

**Evidence:**
[Non-root execution and readable lab secret](img/harden/container_exploit.png)
[missing token and blocked filesystem write](img/harden/container_security_context.png).

**Caption:** The replay confirms the runtime restrictions.

## Slide 14

**Content:**

- **Layer:** Container.
- **Issue:** Noncompliant pods can still be created.
- **Cause:** Missing admission enforcement.
- **Fix:** Enforce the Restricted Pod Security Standard.

**Evidence:**
[Namespace enforcement labels](../argocd/insecure-apps-container/react.yaml)
[rejected test pod](img/harden/container_pss.png).

**Caption:** Namespace admission controls reject the test pod because it fails the Restricted standard.

## Slide 15

**Content:**

Container layer

- No automatically mounted Kubernetes token.
- Restrictive security context.
- Admission rejects noncompliant pods.

Next: patch the vulnerable application.

**Caption:** Container controls reduce privileges and exposed identity. The specialist now patches the application vulnerability that enabled the initial attack.

## Slide 16

**Content:**

- **Layer:** Code.
- **Issue:** The application permits remote code execution.
- **Cause:** Framework dependencies affected by React2Shell.
- **Fix:** Update the vulnerable framework and dependencies.

**Evidence:**
[Dependency update](img/harden/code_react01.png)
[recorded audit result](img/harden/code_react02.png).

**Caption:** The specialist updates the vulnerable dependencies. The recorded audit reports no known vulnerabilities in that dependency snapshot.

## Slide 17

**Content:**

- **Layer:** Code.
- **Issue:** The image runs as root and includes unnecessary tooling.
- **Cause:** Build tools and runtime share the same image.
- **Fix:** Use a multistage build and a minimal distroless runtime with a non-root user.

**Evidence:**
[Secure Dockerfile](../app/Dockerfile.secure)
[recorded image build](img/harden/code_docker_build.png)

**Caption:** A multistage build separates build tooling from the runtime. The production server runs in a minimal image as a non-root user.

## Slide 18

**Content:**

Attack Replay: RCE

- The application responds with `HTTP 200 OK`.
- The exploit request returns `HTTP 404`.
- No command output returns in the recorded replay.

**Evidence:**
[Recorded reachability check and exploit replay](img/harden/code_secure.png).

**Caption:** The application remains reachable, while the recorded React2Shell replay returns no command output.

## Slide 19

**Title:** Code: Summary

**Content:**

Code layer

- Patch the vulnerable application dependencies.
- Harden the production image.

**Caption:** The final stage addresses the application entry point and reduces the runtime image's attack surface.

## Slide 20

**Title:** Hardening Summary Four Layers

**Content:**

| Layer     | Control                             | Recorded result                                             |
| --------- | ----------------------------------- | ----------------------------------------------------------- |
| Cloud     | Remove unnecessary IRSA access      | Previous script cannot assume the role                      |
| Cluster   | RBAC and network isolation          | Secret request forbidden; internal API times out            |
| Container | Runtime and admission controls      | Non-root execution; token absent; root filesystem read-only |
| Code      | Dependency patch and hardened image | Recorded exploit returns no command output                  |

**Caption:** Each layer limits a different part of the attack. The final replay also checks the patched application at the original entry point.

## Slide 21

**Title:** What Comes Next?

**Content:**

The controls are in place.

How do we keep future changes secure?

To be continued: Integrate security practice in CI/CD and Runtime Monitoring

**Caption:** Next, we switch to the DevSecOps perspective and integrate security checks into delivery workflows and runtime monitoring.
