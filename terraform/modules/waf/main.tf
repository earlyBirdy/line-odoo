data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  firehose_stream_name = "${var.name}-waf-logs"
  firehose_stream_arn  = "arn:${data.aws_partition.current.partition}:firehose:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:deliverystream/${local.firehose_stream_name}"

  use_kms = var.log_bucket_kms_key_arn != "" || var.create_kms_key
}

data "aws_iam_policy_document" "kms" {
  count = (var.log_bucket_kms_key_arn == "" && var.create_kms_key) ? 1 : 0

  # Admin control
  statement {
    sid     = "AllowAccountRoot"
    effect  = "Allow"
    actions = ["kms:*"]
    principals { type = "AWS", identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"] }
    resources = ["*"]
  }

  # Allow ONLY the Firehose delivery role (defined below) to use the key,
  # but only when the request is coming via S3 and for objects under our log prefix.
  statement {
    sid    = "AllowFirehoseRoleViaS3ForLogPrefix"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals { type = "AWS", identifiers = [aws_iam_role.firehose.arn] }
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["${var.log_bucket_arn}/${var.log_prefix}/*"]
    }
  }
}

resource "aws_kms_key" "waf_logs" {
  count                   = (var.log_bucket_kms_key_arn == "" && var.create_kms_key) ? 1 : 0
  description             = "KMS key for WAF logs (Firehose -> S3) for ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms[0].json
  tags                    = var.tags
}

resource "aws_kms_alias" "waf_logs" {
  count         = (var.log_bucket_kms_key_arn == "" && var.create_kms_key) ? 1 : 0
  name          = "alias/${var.name}-${var.kms_alias_suffix}"
  target_key_id = aws_kms_key.waf_logs[0].key_id
}

locals {
  effective_kms_arn = var.log_bucket_kms_key_arn != "" ? var.log_bucket_kms_key_arn : (var.create_kms_key ? aws_kms_key.waf_logs[0].arn : "")
}

resource "aws_wafv2_web_acl" "this" {
  name  = "${var.name}-web-acl"
  scope = "REGIONAL"

  default_action { allow {} }

  rule {
    name     = "AWSManagedCommon"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedKnownBadInputs"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-badinputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitWebhook"
    priority = 10
    action { block {} }
    statement {
      rate_based_statement {
        limit              = var.webhook_rate_limit
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string         = var.webhook_path
            positional_constraint = "STARTS_WITH"
            field_to_match { uri_path {} }
            text_transformation { priority = 0 type = "NONE" }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-ratelimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-webacl"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.name}-waf-logs"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_iam_role" "firehose" {
  name = "${var.name}-waf-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = local.firehose_stream_arn
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "firehose" {
  name = "${var.name}-waf-firehose-policy"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          var.log_bucket_arn,
          "${var.log_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = ["${aws_cloudwatch_log_group.firehose.arn}:*"]
      }
      ,
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = local.effective_kms_arn != "" ? [local.effective_kms_arn] : []
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "waf" {
  name        = local.firehose_stream_name
  destination = "extended_s3"
  tags        = var.tags

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = var.log_bucket_arn
    prefix     = "${var.log_prefix}/"

dynamic "encryption_configuration" {
  for_each = local.effective_kms_arn != "" ? [1] : []
  content {
    kms_key_arn = local.effective_kms_arn
  }
}

    buffering_interval = 300
    buffering_size     = 5
    compression_format = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = "S3Delivery"
    }
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf.arn]

  dynamic "redacted_fields" {
    for_each = toset(var.redact_headers)
    content {
      single_header { name = redacted_fields.value }
    }
  }

  dynamic "redacted_fields" {
    for_each = var.redact_query_string ? [1] : []
    content { query_string {} }
  }

  dynamic "redacted_fields" {
    for_each = var.redact_uri_path ? [1] : []
    content { uri_path {} }
  }

  dynamic "redacted_fields" {
    for_each = var.redact_method ? [1] : []
    content { method {} }
  }

  depends_on = [aws_kinesis_firehose_delivery_stream.waf]
}
