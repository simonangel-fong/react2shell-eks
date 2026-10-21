# Post 1: slide copy

Source: [post01_eks_breach.pptx](post01_eks_breach.pptx). Text inside screenshots is excluded.

## Slide 1

React2Shell on Amazon EKS

One vulnerability. Four layers.
Attack. Detect. Harden.

**Caption:** None

## Slide 2

An Attacker's Story

Scenario: the day after React2Shell disclosure (CVE-2025-55182).

An attacker targets an unpatched app at react2shell.arguswatcher.net.

The attack begins…

**Caption:** An attacker finds an unpatched application and tests it for React2Shell. Now the attack begins.

## Slide 3

Attacker / Code / Container / Cluster / Cloud

Root access inside the container

**Caption:** The attacker tries to get the user id and finds tha application runs as root.

## Slide 4

Attacker / Code / Container / Cluster / Cloud

Inspect the runtime environment

**Caption:** Runtime details reveal Debian and help the attacker understand the environment.

## Slide 5

Attacker / Code / Container / Cluster / Cloud

Code Layer

- React2Shell enables code execution in the app.
- The process runs as root on Debian.

Next: explore the container.

**Caption:** Code execution gives the attacker a foothold. Next, the attacker inspects the container.

## Slide 6

Attacker / Code / Container / Cluster / Cloud

Inspect environment variables

- Kubernetes environment detected.
- Container secret found.

**Caption:** Environment variables reveal Kubernetes and a secret available to the app.

## Slide 7

Attacker / Code / Container / Cluster / Cloud

Read the container secret: `CONTAINER_SECRET`

**Caption:** The attacker reads the container secret directly from the process environment.

## Slide 8

Attacker / Code / Container / Cluster / Cloud

Locate and read the service account token

**Caption:** A mounted service account token exposes the pod's Kubernetes identity.

## Slide 9

Attacker / Code / Container / Cluster / Cloud

Query the Kubernetes API server

- API server IP: `172.16.110.140`

**Caption:** The attacker uses the token to authenticate a request to the Kubernetes API.

## Slide 10

Attacker / Code / Container / Cluster / Cloud

Container Layer

- The app runs in Kubernetes.
- Environment variables expose `CONTAINER_SECRET`.
- The mounted service account token allows API authentication.

Next: explore access across the cluster.

**Caption:** The compromised app exposes a secret and a workload identity. Next comes cluster access.

## Slide 11

Attacker / Code / Container / Cluster / Cloud

Internal API discovered

- Namespace: `internal`
- Port: `3000`

**Caption:** The attacker discovers an internal API listening on port 3000 in another namespace.

## Slide 12

Attacker / Code / Container / Cluster / Cloud

Read data from the internal API

- Two user records exposed: Alice and Bob.

**Caption:** A request from the compromised pod returns two internal user records: Alice and Bob.

## Slide 13

Attacker / Code / Container / Cluster / Cloud

Cluster secret discovered

- Secret: `cluster-secret`
- Namespace: `internal`

**Caption:** The Kubernetes API reveals a secret in the internal namespace.

## Slide 14

Attacker / Code / Container / Cluster / Cloud

Read and decode the cluster secret

- Retrieve `cluster-secret` from the `internal` namespace.
- Decode its value.

**Caption:** Broad RBAC permissions let the attacker retrieve the secret and decode its value.

## Slide 15

Attacker / Code / Container / Cluster / Cloud

Cluster Layer

- Internal API data exposed.
- Cluster secret retrieved.

Next: explore the pod's AWS access.

**Caption:** Internal data and the cluster secret are exposed. The attacker now investigates the cloud layer identity.

## Slide 16

Attacker / Code / Container / Cluster / Cloud

AWS identity discovered

- `AWS_*` variables reveal region `ca-central-1`.
- The pod has an IAM role and a web identity token file.
- IRSA role: `react2shell-eks-insecure-pod-irsa`

**Caption:** AWS environment variables identify the IAM role and the separate IRSA token file.

## Slide 17

Attacker / Code / Container / Cluster / Cloud

IRSA lets EKS pods assume IAM roles

- The role's permissions determine access to AWS services.

EKS pod

Assume IAM role

AWS Secrets Manager

**Caption:** IRSA exchanges the projected token for temporary AWS credentials. The role's permissions determine access.

## Slide 18

Attacker / Code / Container / Cluster / Cloud

Create and upload a script to the pod

**Caption:** The attacker uploads a Node.js script to use the pod's AWS identity.

## Slide 19

Attacker / Code / Container / Cluster / Cloud

List secrets in AWS Secrets Manager

- A lab RDS credential is found.

**Caption:** Using the pod's AWS role, the attacker lists secrets and finds a RDS credential.

## Slide 20

Attacker / Code / Container / Cluster / Cloud

Retrieve the lab RDS credential

- Username
- Password
- Port

**Caption:** Secrets Manager returns the RDS credential, including its username, password, and port.

## Slide 21

Attacker / Code / Container / Cluster / Cloud

Cloud Layer

- Script uploaded and executed in the pod.
- Cloud secret retrieved.

All three lab secrets exposed.

**Caption:** The script retrieves the cloud secret, completing access to all three secrets.

## Slide 22

Attack Chain Summary

diagram

**Caption:** The app vulnerability enables remote code execution.

## Slide 23

Attack Chain Summary

diagram

**Caption:** Readable environment variables exposes container secret.

## Slide 24

Attack Chain Summary

diagram

**Caption:** A mounted token makes the API server and the cluster secret accessible due to broad RBAC.

## Slide 25

Attack Chain Summary

diagram

**Caption:** The flat network in cluster exposes internal data.

## Slide 26

Attack Chain Summary

diagram

**Caption:** IRSA injected token and assume role expose the IAM role credentials. And broad IAM permissions allow secret access.

## Slide 27

The secrets are exposed. What happens next?
How does a platform administrator detect the breach and respond?
To be continued: Incident Response on EKS

**Caption**: “The attacker has reached the secrets. Next, we switch to the platform administrator’s perspective to detect the breach, investigate the evidence, and contain the compromised pod.”
