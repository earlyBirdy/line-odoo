variable "name" { type = string }
variable "tags" { type = map(string) default = {} }

variable "bucket_name" { type = string }

variable "s3_prefix" {
  type        = string
  description = "Object key prefix (without leading slash). Example: waf/dev"
}

variable "firehose_stream_name" {
  type        = string
  description = "Firehose delivery stream name. Used to construct stream ARN for SourceArn restriction (where supported)."
}

variable "delivery_role_name" {
  type        = string
  description = "IAM role name assumed by Firehose to deliver objects to S3."
}

variable "kms_alias_suffix" {
  type    = string
  default = "waf-logs"
}

# Safety knob: if true, add an IfExists restriction on aws:SourceArn to the delivery stream ARN.
# Some services do not pass aws:SourceArn to KMS via S3; IfExists avoids breaking delivery.
variable "restrict_source_arn_if_exists" {
  type    = bool
  default = true
}
