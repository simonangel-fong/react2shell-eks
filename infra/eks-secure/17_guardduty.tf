# guardduty.tf

# ##############################
# GuardDuty: behavioral detection, no hand-written rules.
# ##############################

resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# Cluster plane: consumes the EKS audit log
resource "aws_guardduty_detector_feature" "eks_audit" {
  detector_id = aws_guardduty_detector.main.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

# Container plane: managed eBPF agent 
resource "aws_guardduty_detector_feature" "runtime" {
  detector_id = aws_guardduty_detector.main.id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}
