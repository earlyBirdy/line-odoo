variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }

variable "backend_port" { type = number default = 8000 }
variable "odoo_port" { type = number default = 8069 }

variable "backend_health_path" { type = string default = "/health" }
variable "odoo_health_path" { type = string default = "/" }

variable "backend_path_patterns" { type = list(string) default = ["/api/*", "/health", "/line/*"] }
variable "odoo_path_patterns" { type = list(string) default = ["/*"] }

variable "acm_certificate_arn" { type = string }
variable "ssl_policy" { type = string default = "ELBSecurityPolicy-TLS13-1-2-2021-06" }

variable "tags" { type = map(string) default = {} }

variable "enable_access_logs" { type = bool default = true }
variable "access_logs_bucket" { type = string default = "" }
variable "access_logs_prefix" { type = string default = "alb" }
