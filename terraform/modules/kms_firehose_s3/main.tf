data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}"
  role_arn   = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.delivery_role_name}"

  firehose_stream_arn = "arn:${data.aws_partition.current.partition}:firehose:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:deliverystream/${var.firehose_stream_name}"
}

# This CMK is intended for Firehose -> S3 deliveries.
# Tightening:
# - Principal pinned to the specific delivery role
# - KMS use only via S3 in this region
# - Encryption context limited to objects under the configured prefix
# - Optional IfExists restriction on aws:SourceArn to the delivery stream ARN
#
# NOTE: Firehose/S3 may not always pass aws:SourceArn to KMS for SSE-KMS on S3 destinations.
# We therefore use *IfExists* by default to avoid breaking delivery.

data "aws_iam_policy_document" "kms" {
  statement {
    sid     = "AllowAccountRoot"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "AllowDeliveryRoleViaS3ForPrefix"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals {
      type        = "AWS"
      identifiers = [local.role_arn]
    }
    resources = ["*"]

    # Enforce that KMS is only called via S3 in-region (recommended by AWS examples).
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }

    # Enforce object-prefix scope via the standard S3 encryption context.
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = ["${local.bucket_arn}/${var.s3_prefix}*"]
    }

    # Best-effort tightening to a single delivery stream where the service passes SourceArn.
    dynamic "condition" {
      for_each = var.restrict_source_arn_if_exists ? [1] : []
      content {
        test     = "StringEqualsIfExists"
        variable = "aws:SourceArn"
        values   = [local.firehose_stream_arn]
      }
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "KMS key for Firehose->S3 deliveries (${var.name})"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}-${var.kms_alias_suffix}"
  target_key_id = aws_kms_key.this.key_id
}
