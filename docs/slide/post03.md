**React2Shell on EKS — 3/4: The Security Specialist’s Perspective**

One vulnerability. Four layers. Four perspectives.

The compromised pod was quarantined. Would the same attack still work after hardening?

In my Amazon EKS project, I took on the role of a security specialist to address the weaknesses behind the simulated React2Shell breach (CVE-2025-55182).

I hardened the environment across the 4C security model, replaying the attack after each stage:

**Cloud → Cluster → Container → Code**

- **Cloud:** removed the application’s unnecessary AWS role and identity association.
- **Cluster:** restricted access to Kubernetes secrets and isolated the internal API using NetworkPolicies.
- **Container:** limited process privileges and filesystem writes, disabled automatic Kubernetes token mounting, and enforced workload security requirements.
- **Code:** patched vulnerable dependencies and built a minimal production image.

**Result:** The original React2Shell attack no longer succeeded against the hardened application, while the application remained available.

**Takeaway:** React2Shell gave the attacker a foothold. Unnecessary privileges and access extended the attack’s reach into cluster and cloud resources. Hardening brought me back to a fundamental principle: least privilege—give the application only the access it needs to do its job.

The video follows each hardening stage and its attack replay.

Next: the DevSecOps engineer’s perspective—integrating security checks into delivery and runtime monitoring.

Project website:
https://react2shell-eks.arguswatcher.net/

GitHub code and walkthroughs:
https://github.com/simonangel-fong/react2shell-eks

#Kubernetes #PlatformEngineering #CloudSecurity

---

## Attachments and publishing notes

These notes are for publishing preparation; copy the post text above into LinkedIn.

- **Video — upload to the main post:** [react2shell_eks_p03_harden.mp4](../video/post/react2shell_eks_p03_harden.mp4).
- **Image — add to the first comment:** [post03_hardening.drawio.png](../img/diagram/post03_hardening.drawio.png), showing the hardening controls across the four layers.
