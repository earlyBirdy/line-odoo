data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.name}-logs"
  use_kms     = var.encryption_mode == "SSE-KMS"
  kms_arn     = local.use_kms ? (var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.this[0].arn) : null
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Default encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? local.kms_arn : null
    }
    bucket_key_enabled = local.use_kms
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

# Optional CMK for log buckets (WAF/Firehose recommended). ALB access logs do NOT support SSE-KMS.
data "aws_iam_policy_document" "kms" {
  count = local.use_kms && var.kms_key_arn == "" ? 1 : 0

  statement {
    sid     = "AllowAccountRoot"
    effect  = "Allow"
    actions = ["kms:*"]
    principals { type = "AWS", identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"] }
    resources = ["*"]
  }

  # Allow Kinesis Data Firehose to use this key (restricted to same account).
  statement {
    sid    = "AllowFirehoseUse"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals { type = "Service", identifiers = ["firehose.amazonaws.com"] }
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "this" {
  count                   = local.use_kms && var.kms_key_arn == "" ? 1 : 0
  description             = "KMS key for ${local.bucket_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms[0].json
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  count         = local.use_kms && var.kms_key_arn == "" ? 1 : 0
  name          = "alias/${var.name}-${var.kms_alias_suffix}"
  target_key_id = aws_kms_key.this[0].key_id
}

# Bucket policy (TLS-only + optional ALB delivery + optional SSE-KMS enforcement)
data "aws_iam_policy_document" "bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
    principals { type = "*", identifiers = ["*"] }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = (local.use_kms && var.deny_unencrypted_puts) ? [1] : []
    content {
      sid     = "DenyUnEncryptedObjectUploads"
      effect  = "Deny"
      actions = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]
      principals { type = "*", identifiers = ["*"] }

      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["aws:kms"]
      }
    }
  }

  dynamic "statement" {
    for_each = (local.use_kms && var.deny_unencrypted_puts) ? [1] : []
    content {
      sid     = "DenyWrongKmsKey"
      effect  = "Deny"
      actions = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]
      principals { type = "*", identifiers = ["*"] }

      condition {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
        values   = [local.kms_arn]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enable_alb_log_delivery ? [1] : []
    content {
      sid     = "AllowELBLogDelivery"
      effect  = "Allow"
      actions = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.this.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
      principals {
        type        = "Service"
        identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enable_alb_log_delivery ? [1] : []
    content {
      sid     = "AllowELBLogDeliveryAclCheck"
      effect  = "Allow"
      actions = ["s3:GetBucketAcl"]
      resources = [aws_s3_bucket.this.arn]
      principals {
        type        = "Service"
        identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json
}
