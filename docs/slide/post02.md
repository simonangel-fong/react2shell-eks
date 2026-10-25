**React2Shell on EKS — 2/4: The Platform Administrator’s Perspective**

One vulnerability. Four layers. Four perspectives.

A cloud secret was accessed. Which application was responsible, and how could I contain it while preserving evidence?

In my Amazon EKS project, I took on the role of a platform administrator to investigate the same simulated React2Shell breach (CVE-2025-55182).

I followed the evidence back through three layers of the 4C security model:

**Cloud → Cluster → Container**

- **Cloud:** reviewed AWS CloudTrail records to identify the AWS identity involved and the secret accessed.
- **Cluster:** traced that identity to the Kubernetes service account and located the affected workload.
- **Container:** correlated application logs with the cloud activity to confirm secret exposure.

I then preserved evidence, paused Argo CD’s automatic sync, removed the compromised pod from service traffic, and quarantined it using a NetworkPolicy while retaining it for investigation.

**Result:** The compromised workload was contained, with evidence preserved for investigation.

**Takeaway:** Effective containment limits further damage while preserving evidence. Keeping the compromised workload available for investigation helps investigators establish the root cause and the full scope of the breach.

The video follows the investigation, containment, and escalation.

Next: the security specialist’s perspective—hardening all four layers and replaying the attack.

Project website:
https://react2shell-eks.arguswatcher.net/

GitHub code and walkthroughs:
https://github.com/simonangel-fong/react2shell-eks

#IncidentResponse #Kubernetes #CloudSecurity

---

## Attachments and publishing notes

These notes are for publishing preparation; copy the post text above into LinkedIn.

- **Video — upload to the main post:** [react2shell_eks_p02_response.mp4](../video/post/react2shell_eks_p02_response.mp4).
