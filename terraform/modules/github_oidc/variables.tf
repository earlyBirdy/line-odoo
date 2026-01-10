variable "role_name" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string }
variable "github_branch" { type = string default = "main" }
variable "tf_state_bucket" { type = string }
variable "tf_lock_table_arn" { type = string }
variable "oidc_thumbprint" {
  type        = string
  description = "GitHub OIDC thumbprint. Default is commonly used, but verify for your region/security requirements."
  default     = "6938fd4d98bab03faadb97b34396831e3780aea1"
}
variable "tags" { type = map(string) default = {} }
