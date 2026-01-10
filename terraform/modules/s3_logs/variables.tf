variable "name" { type = string }
variable "tags" { type = map(string) default = {} }
variable "force_destroy" { type = bool default = false }

# Optional explicit bucket name
variable "bucket_name" { type = string default = "" }

# If true, attach the bucket policy statements required for ALB log delivery.
variable "enable_alb_log_delivery" { type = bool default = false }

# Security hardening
variable "enforce_tls_only" { type = bool default = true }

# Encryption mode:
# - "SSE-S3" (recommended/required for ALB access logs)
# - "SSE-KMS" (recommended for WAF/Firehose logs)
variable "encryption_mode" {
  type    = string
  default = "SSE-S3"
  validation {
    condition     = contains(["SSE-S3", "SSE-KMS"], var.encryption_mode)
    error_message = "encryption_mode must be one of: SSE-S3, SSE-KMS"
  }
}

# If encryption_mode == "SSE-KMS" and kms_key_arn is empty, this module creates a dedicated CMK.
variable "kms_key_arn" { type = string default = "" }

# Alias suffix for the created key (when kms_key_arn is empty and encryption_mode == SSE-KMS)
variable "kms_alias_suffix" { type = string default = "logs" }

# If true and encryption_mode == SSE-KMS, deny PutObject requests that do not request SSE-KMS.
# NOTE: Do NOT enable this for ALB access logs; ALB supports only SSE-S3.
variable "deny_unencrypted_puts" { type = bool default = true }
