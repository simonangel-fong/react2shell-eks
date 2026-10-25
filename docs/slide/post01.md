**React2Shell on EKS — 1/4: The Attacker’s Perspective**

One vulnerability. Four layers. Four perspectives.

How far can one vulnerable application reach in a cloud environment?

After earning my CKS certification, I built an intentionally insecure environment on Amazon EKS to explore that question.

The starting point was **React2Shell (CVE-2025-55182)**, a critical vulnerability in React Server Components disclosed in December 2025. It allows an attacker to execute code in an affected application without logging in.

I simulated an attack across the four layers of the Kubernetes 4C security model:

**Code → Container → Cluster → Cloud**

- **Code:** exploited the vulnerable application to execute commands.
- **Container:** read an exposed secret and discovered the application’s workload identities.
- **Cluster:** used excessive permissions and unrestricted network access to retrieve a Kubernetes secret and internal user records.
- **Cloud:** used the application’s AWS identity and broad permissions to retrieve a lab database credential.

**Result:** Three lab secrets and internal user records were exposed, starting from one compromised application.

**Takeaway:** A trusted identity can carry an attacker’s actions when the application behind it is compromised. In this breach, credentials supplied to the workload allowed the attacker to authenticate to Kubernetes and AWS as the application.

The video follows the attack across all four layers.

Next: the platform administrator’s perspective—tracing the activity and containing the compromised workload.

Project website:
https://react2shell-eks.arguswatcher.net/

GitHub code and walkthroughs:
https://github.com/simonangel-fong/react2shell-eks

#Kubernetes #AWS #CloudSecurity

---

## Attachments and publishing notes

These notes are for publishing preparation; copy the post text above into LinkedIn.

- **Video — upload to the main post:** [react2shell_eks_p01_attack.mp4](../video/post/react2shell_eks_p01_attack.mp4).
- **Image — add to the first comment:** [post01_attack_chain.drawio.png](../img/diagram/post01_attack_chain.drawio.png), showing the attack chain across Code → Container → Cluster → Cloud.

LinkedIn supports uploaded MP4 videos and PNG images, but separate video and image attachments cannot be combined in a standard post. Upload the video to the post and share the diagram in a comment. Alternatively, LinkedIn lets you upload a custom video thumbnail; the diagram could serve as the thumbnail if it remains readable at preview size.

Sources checked on October 25, 2026:

- [React advisory: CVE-2025-55182](https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components).
- [LinkedIn Help: supported media formats](https://www.linkedin.com/help/linkedin/answer/a564109/supported-providers-and-content-types-for-work-samples-on-your-profile).
- [LinkedIn Help: video upload and custom thumbnails](https://www.linkedin.com/help/linkedin/answer/a7486279).
- [Taplio Help: video and image posting limitation](https://intercom.help/taplio/en/articles/14895012-posting-guidelines).
