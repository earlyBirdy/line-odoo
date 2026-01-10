output "bucket_name" { value = aws_s3_bucket.this.bucket }
output "bucket_arn" { value = aws_s3_bucket.this.arn }
output "kms_key_arn" { value = local.kms_arn }
