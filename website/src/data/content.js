export const REPO_URL = "https://github.com/simonangel-fong/react2shell-eks";

// Every stage currently shows a figure, so nothing calls video() yet. The
// plumbing stays for when the demo recordings go up: set a stage's videoUrl
// instead of its figure and Stage renders the player.
// Videos are served from S3 behind CloudFront, never bundled.
const VIDEO_BASE = import.meta.env.VITE_VIDEO_BASE_URL?.replace(/\/$/, "") ?? "";
const video = (file) => (VIDEO_BASE ? `${VIDEO_BASE}/${file}` : null);

export const layers = ["code", "container", "cluster", "cloud"];

export const perspectives = [
  "attacker",
  "platform administrator",
  "security specialist",
  "DevSecOps engineer",
];

// Four stages of the project, in the order the README tells them. `tone`
// carries the arc: the breach is red, the response and defenses turn cool.
export const stages = [
  {
    id: "attack",
    index: "01",
    label: "Attack",
    tone: "breach",
    // Coloured wherever it appears in this section, matching the heading.
    term: "React2Shell",
    heading: "Application Breach with React2Shell",
    lead: "An attacker exploits React2Shell to execute commands inside the application container.",
    body: "The breach exposes container secrets, Kubernetes resources, an internal API, and a dummy RDS credential in AWS Secrets Manager through an overly permissive IRSA role.",
    figure: {
      src: "/diagram-attack-chain.png",
      webp: "/diagram-attack-chain.webp",
      width: 1600,
      height: 901,
      alt: "Attack chain: React2Shell gives remote code execution in the app pod, which reads the container secret from its environment, uses the service account token to reach the Kubernetes API server and read a cluster secret, reaches internal API data over the flat network, and assumes an IRSA role to read an RDS credential from AWS Secrets Manager.",
      caption: "Attack chain across code, container, cluster, and cloud",
    },
  },
  {
    id: "respond",
    index: "02",
    label: "Respond",
    tone: "signal",
    heading: "Investigation and Containment",
    lead: "The platform administrator traces credential access using CloudTrail events and pod logs.",
    body: "They pause Argo CD reconciliation, preserve evidence, isolate the pod, and document the incident.",
    figure: {
      src: "/respond-netpol.png",
      width: 1375,
      height: 487,
      alt: "kubectl describe of the quarantine-isolate NetworkPolicy in the react namespace: it selects app=quarantined, allows no ingress and no egress traffic, and applies both Ingress and Egress policy types.",
      caption: "Pod isolation through blocked ingress and egress",
    },
  },
  {
    id: "harden",
    index: "03",
    label: "Harden",
    tone: "signal",
    heading: "Defense in Depth",
    lead: "The security specialist removes broad cloud permissions, restricts RBAC, enforces NetworkPolicies, and hardens pod security settings.",
    body: "Replaying the attack after each change shows where access is blocked. Patching the application and using a non-root distroless image complete the hardening.",
    figure: {
      src: "/diagram-hardening.png",
      webp: "/diagram-hardening.webp",
      width: 1600,
      height: 901,
      alt: "Hardening controls across the same four layers the attack crossed: patched dependencies and a hardened image stop the remote code execution, a non-root security context and no service account token close the container, network policy and RBAC block the cluster secret and internal API, and least-privilege IAM denies the RDS credential in AWS Secrets Manager.",
      caption: "Defenses across code, container, cluster, and cloud",
    },
  },
  {
    id: "integrate",
    index: "04",
    label: "Integrate",
    tone: "signal",
    heading: "DevSecOps",
    lead: "Shift left: the DevSecOps engineer adds Trivy checks in GitHub Actions for dependencies, images, Kubernetes manifests, and Terraform.",
    body: "Monitoring: cloud audit logs support investigation; a sample finding verifies the GuardDuty to EventBridge to SNS alert path.",
    figure: {
      src: "/integrate-pipeline.png",
      webp: "/integrate-pipeline.webp",
      width: 1863,
      height: 748,
      alt: "A successful ci-image.yml run in GitHub Actions, gated in three stages: Dockerfile misconfiguration scan, then build with image scan and SBOM, then push to the registry on master only.",
      caption: "GitHub Actions workflow: build, scan, and publish",
    },
  },
];
