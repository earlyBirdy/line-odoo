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
