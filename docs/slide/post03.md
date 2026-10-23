**Would the same attack still work after hardening?**

In my React2Shell security project on Amazon Elastic Kubernetes Service (EKS), I tested the controls by replaying the attack after each hardening stage.

**React2Shell on EKS, Part 3 of 4: The security specialist's perspective.**

I worked across four layers:

- **Cloud**: removed the application's unnecessary AWS role and identity association.
- **Cluster**: restricted secret-read permissions and isolated the internal API.
- **Container**: limited process privileges and file writes, removed the Kubernetes token, and enforced workload security requirements.
- **Code**: updated vulnerable dependencies and built a minimal production image.

The results gave each change a concrete test: the secret request returned Forbidden, the internal API request timed out, and filesystem writes failed.

In the final replay, the application remained reachable while the exploit returned no command output.

The staged tests showed how access controls could limit exposure while the application was still vulnerable. Patching addressed the original entry point.

The video pairs each control with the recorded result, making the hardening work reviewable.

Next: keeping security checks in the delivery workflow.

Project code and walkthroughs:
https://github.com/simonangel-fong/react2shell-eks

#Kubernetes #PlatformEngineering #CloudSecurity
