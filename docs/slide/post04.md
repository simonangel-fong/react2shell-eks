**React2Shell on EKS — 4/4: The DevSecOps Engineer’s Perspective**

One vulnerability. Four layers. Four perspectives.

The environment is hardened. How do security improvements survive the next change?

For the final part of my Amazon EKS project, I took on the role of a DevSecOps engineer to integrate lessons from the React2Shell breach (CVE-2025-55182) into delivery and operations.

I added four GitHub Actions workflows covering the 4C security model:

**Code · Container · Cluster · Cloud**

- **Code:** check dependencies and scan for exposed secrets.
- **Container:** scan images and generate an inventory of their components.
- **Cluster:** check Kubernetes manifests for security misconfigurations.
- **Cloud:** validate and scan Terraform infrastructure configuration.

Pipeline jobs fail when findings meet the configured blocking criteria. I also routed GuardDuty findings to the administrator by email, testing delivery with a sample finding.

**Result:** The project now has repeatable security checks during delivery and a verified route for runtime alerts.

**Takeaway:** A resilient application needs security checks early across Code, Container, Cluster, and Cloud, followed by ongoing monitoring after deployment. Shift-left checks help catch weaknesses before release; runtime monitoring helps surface signs of compromise while the system is running.

The video covers the workflows, the alert demonstration, and possible future extensions.

**Project wrap-up:** This project began with a question after earning my CKS certification: how do these skills come together in a cloud environment? React2Shell on EKS became a documented case study connecting application security, incident response, platform hardening, and everyday delivery—through one vulnerability and four perspectives.

Project website:
https://react2shell-eks.arguswatcher.net/

GitHub code and walkthroughs:
https://github.com/simonangel-fong/react2shell-eks

#DevSecOps #GitHubActions #AWS

---

## Attachments and publishing notes

These notes are for publishing preparation; copy the post text above into LinkedIn.

- **Video — upload to the main post:** [react2shell_eks_p04_devsecops.mp4](../video/post/react2shell_eks_p04_devsecops.mp4).
- **Image — add to the first comment:** [summary.drawio.png](../img/diagram/summary.drawio.png), bringing together the four perspectives across the four layers.

The GuardDuty demonstration uses a sample finding to verify notification delivery. Policy as code, centralized secret management, and deeper observability are presented as future extensions in the video.
