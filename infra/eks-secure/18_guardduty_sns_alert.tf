# guardduty_sns_alert.tf

# ##############################
# Alert: GuardDuty finding -> EventBridge -> SNS -> email.
# ##############################

resource "aws_sns_topic" "alert" {
  name = "${local.common_name}-guardduty-alert"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alert.arn
  protocol  = "email"
  endpoint  = var.alert_email # confirm the subscription from the email AWS sends
}

resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "${local.common_name}-guardduty"
  description = "GuardDuty findings, Medium severity and above."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule = aws_cloudwatch_event_rule.guardduty.name
  arn  = aws_sns_topic.alert.arn

  # flatten the finding into a short readable message
  input_transformer {
    input_paths = {
      type     = "$.detail.type"
      severity = "$.detail.severity"
      region   = "$.detail.region"
    }
    input_template = "\"[GuardDuty <severity>] <type> (<region>)\""
  }
}

# allow EventBridge to publish to the topic
data "aws_iam_policy_document" "sns_publish" {
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alert.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alert" {
  arn    = aws_sns_topic.alert.arn
  policy = data.aws_iam_policy_document.sns_publish.json
}
