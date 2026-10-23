**A cloud secret was accessed. Which application was responsible?**

In my React2Shell security project on Amazon Elastic Kubernetes Service (EKS), I switched from the attacker's perspective to the platform administrator's.

**React2Shell on EKS, Part 2 of 4: Incident response.**

The priority was to identify the affected workload and limit its access while preserving evidence.

I followed the investigation through to containment:

- Correlated AWS CloudTrail audit records with application logs, confirming two reads of the same lab credential.
- Paused Argo CD's automatic configuration sync before making emergency changes.
- Removed the compromised application instance from service traffic and applied network quarantine, retaining it for investigation.
- Prepared an incident report separating completed containment from the remaining credential-cleanup actions.

One lesson stood out: isolating an application does not invalidate credentials an attacker may have copied. Credential rotation and review of active cloud sessions require their own follow-through.

The video shows how I connected the evidence and documented that boundary.

Next: hardening the environment and replaying the attack.

Project code and walkthroughs:
https://github.com/simonangel-fong/react2shell-eks

#IncidentResponse #Kubernetes #CloudSecurity
