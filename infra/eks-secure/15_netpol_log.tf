# netpol_log.tf

# ##############################
# IAM policy: enable Network policy loggings
# The VPC CNI node agent ships its allow/deny verdicts to CloudWatch itself.
# ##############################
data "aws_iam_policy_document" "netpol_log" {
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "netpol_log" {
  name        = "${local.common_name}-netpol-log"
  description = "Let the VPC CNI node agent ship network policy verdicts to CloudWatch."
  policy      = data.aws_iam_policy_document.netpol_log.json
}

resource "aws_iam_role_policy_attachment" "netpol_log" {
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
  policy_arn = aws_iam_policy.netpol_log.arn
}

# ####################
# debug: if the log group stays empty, restart the agent:
#   kubectl -n kube-system rollout restart ds/aws-node
# ####################
