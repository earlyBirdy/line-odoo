variable "name" { type = string }
variable "alb_arn" { type = string }
variable "webhook_path" { type = string default = "/line/webhook" }
variable "webhook_rate_limit" { type = number default = 300 }
variable "tags" { type = map(string) default = {} }

variable "log_bucket_arn" { type = string }
variable "log_bucket_name" { type = string }
variable "log_prefix" { type = string default = "waf" }

variable "redact_headers" { type = list(string) default = ["authorization", "cookie", "x-line-signature"] }
variable "redact_query_string" { type = bool default = true }
variable "redact_uri_path" { type = bool default = false }
variable "redact_method" { type = bool default = false }


# Optional: KMS key for Firehose S3 destination encryption (recommended).
variable "log_bucket_kms_key_arn" { type = string default = "" }

# If true and log_bucket_kms_key_arn is empty, create a dedicated CMK for WAF log delivery.
variable "create_kms_key" {
  type    = bool
  default = true
}

variable "kms_alias_suffix" {
  type    = string
  default = "waf-logs"
}
