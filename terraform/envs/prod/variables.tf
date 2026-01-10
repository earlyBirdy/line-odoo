variable "aws_region" { type = string default = "ap-southeast-1" }
variable "vpc_cidr" { type = string default = "10.30.0.0/16" }
variable "az_count" { type = number default = 2 }

variable "alb_ingress_cidrs" { type = list(string) default = ["0.0.0.0/0"] }
variable "enable_https" { type = bool default = false }
variable "log_retention_days" { type = number default = 30 }

variable "db_username" { type = string default = "odoo" }
variable "db_password" { type = string sensitive = true }
variable "db_name" { type = string default = "odoo" }
variable "db_instance_class" { type = string default = "db.t4g.medium" }
variable "skip_final_snapshot" { type = bool default = true }
variable "deletion_protection" { type = bool default = false }

variable "redis_node_type" { type = string default = "cache.t4g.micro" }

variable "backend_image" { type = string }
variable "odoo_image" { type = string }
variable "backend_env" { type = list(object({name=string,value=string})) default = [] }
variable "odoo_env" { type = list(object({name=string,value=string})) default = [] }

variable "desired_count" { type = number default = 1 }

# Secrets Manager ARNs the tasks need to read (optional)
variable "secret_arns" { type = list(string) default = [] }


# --- HTTPS / ACM ---
variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for ALB HTTPS listener (must be in same region)."
}

# --- GitHub OIDC (Terraform deploy role) ---
variable "github_oidc_role_name" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string }
variable "github_branch" { type = string default = "main" }

# Terraform remote state access (for GitHub Actions role policy)
variable "tf_state_bucket" { type = string }
variable "tf_lock_table_arn" { type = string }

# --- WAF ---
variable "waf_webhook_path" { type = string default = "/line/webhook" }
variable "waf_webhook_rate_limit" { type = number default = 300 }


variable "hosted_zone_name" { type = string }
variable "domain_api" { type = string }
variable "domain_odoo" { type = string }
variable "create_route53_alias_records" { type = bool default = true }
variable "waf_log_prefix" { type = string default = "waf" }
variable "alb_log_prefix" { type = string default = "alb" }
variable "force_destroy_log_bucket" { type = bool default = false }
