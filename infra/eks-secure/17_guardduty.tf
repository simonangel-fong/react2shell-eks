# guardduty.tf

# ##############################
# GuardDuty (monitoring phase) - behavioral detection, no hand-written rules.
# Reads the logs enabled earlier and the runtime agent, baselines normal
# activity per cluster/principal, and flags the breach as anomalies:
#   container -> Execution:Runtime/ReverseShell
#   cluster   -> CredentialAccess:Kubernetes/AnomalousBehavior.SecretsAccessed
#   cloud     -> CredentialAccess:IAMUser/AnomalousBehavior
#   all       -> AttackSequence:EKS/CompromisedCluster (Extended Threat Detection)
# ##############################

resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# Cluster plane: consumes the EKS audit log enabled in 11_eks.tf.
resource "aws_guardduty_detector_feature" "eks_audit" {
  detector_id = aws_guardduty_detector.main.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

# Container plane: managed eBPF agent (the Falco equivalent), auto-installed
# as the aws-guardduty-agent EKS addon.
# RUNTIME_MONITORING supersedes the older EKS_RUNTIME_MONITORING - using both
# errors. This one covers EC2/ECS/EKS under a single feature.
resource "aws_guardduty_detector_feature" "runtime" {
  detector_id = aws_guardduty_detector.main.id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}
