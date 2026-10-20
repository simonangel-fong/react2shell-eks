# cloudtrail.tf

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ##############################
# S3 bucket: CloudTrail
# ##############################
resource "aws_s3_bucket" "trail" {
  bucket        = "${local.common_name}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # allow destroy with logs present
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Policy: allow CloudTrail to write to the bucket.
data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${local.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${local.common_name}-trail"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket.json
}

# ##############################
# CloudWatch Logs: cloudtrail
# ##############################
resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${local.common_name}"
  retention_in_days = local.eks_log_retention_days
}

# ##############################
# IAM: allow CloudWatch to log CloudTrail
# ##############################

# Role CloudTrail assumes to write into the log group.
data "aws_iam_policy_document" "trail_cw_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "trail_cw" {
  name               = "${local.common_name}-cloudtrail-cw"
  assume_role_policy = data.aws_iam_policy_document.trail_cw_assume.json
}

data "aws_iam_policy_document" "trail_cw" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "trail_cw" {
  name   = "cloudwatch-logs"
  role   = aws_iam_role.trail_cw.id
  policy = data.aws_iam_policy_document.trail_cw.json
}

# ##############################
# CloudTrail: the AWS API plane system of record.
# ##############################
resource "aws_cloudtrail" "main" {
  name           = "${local.common_name}-trail"
  s3_bucket_name = aws_s3_bucket.trail.id

  include_global_service_events = true # STS is global
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*" # cloudwatch log
  cloud_watch_logs_role_arn  = aws_iam_role.trail_cw.arn                 # IAM: allow to log in CloudWatch

  # read write all events
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [
    aws_s3_bucket_policy.trail,
    aws_iam_role_policy.trail_cw,
  ]
}
