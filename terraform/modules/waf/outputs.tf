output "web_acl_arn" { value = aws_wafv2_web_acl.this.arn }

output "firehose_stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.waf.arn
}

output "firehose_role_arn" {
  value = aws_iam_role.firehose.arn
}

output "kms_key_arn" {
  value = local.effective_kms_arn
}
