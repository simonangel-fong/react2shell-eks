**How do security improvements survive the next deployment?**

For the final part of my personal React2Shell security lab on Amazon Elastic Kubernetes Service (EKS), I integrated checks into delivery and operations.

**React2Shell on EKS, Part 4 of 4: The DevSecOps engineer's perspective.**

I implemented:

- Four GitHub Actions workflows covering dependencies, images, Kubernetes manifests, and Terraform infrastructure.
- Pipeline jobs that fail on findings covered by the configured severity thresholds and exceptions.
- Scan reports and a software bill of materials (SBOM), an inventory of the image's components, for review.
- An AWS alert route that delivers GuardDuty findings to an administrator by email.

The recorded image workflow completes successfully. A sample GuardDuty finding confirms that the email notification reaches its destination.

The workflows provide feedback before deployment, while monitoring adds visibility afterward. Findings still need investigation, ownership, and remediation.

The video also outlines future options for policy enforcement, centralized secret management, and deeper observability, clearly separated from the demonstrated work.

The series connects application behavior and access controls to incident response and delivery automation.

I'd welcome feedback from platform engineering and DevSecOps teams working on similar challenges.

Project code and walkthroughs:
https://github.com/simonangel-fong/react2shell-eks

#DevSecOps #GitHubActions #AWS
