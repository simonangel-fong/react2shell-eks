**How far can one vulnerable application reach in a cloud environment?**

After earning my Certified Kubernetes Security Specialist (CKS) certification, I wanted to apply those skills to a complete security scenario.

I built a project on Amazon Elastic Kubernetes Service (EKS) around React2Shell, a vulnerability that allows an attacker to execute commands in an affected application.

**React2Shell on EKS, Part 1 of 4: The attacker's perspective.**

In this intentionally insecure environment, I demonstrated how a compromised application could:

- Read a secret from its own container environment.
- Use excessive Kubernetes permissions to read a cluster secret.
- Reach an internal API and retrieve lab user records.
- Use its AWS identity and broad permissions to retrieve a synthetic cloud credential.

The Kubernetes and AWS access paths both started from the compromised application. Their permissions determined how far the attack could go.

That is the engineering question I wanted to explore: how can platform controls limit the impact of an application vulnerability?

The video walks through the evidence. All credentials and user records shown are lab data.

Next: investigating the same activity from the platform administrator's perspective.

Project code and walkthroughs:
https://github.com/simonangel-fong/react2shell-eks

#Kubernetes #AWS #CloudSecurity
