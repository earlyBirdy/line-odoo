variable "name" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "sg_rds_id" { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string sensitive = true }
variable "db_name" { type = string default = "odoo" }
variable "engine_version" { type = string default = "15.8" }
variable "instance_class" { type = string default = "db.t4g.medium" }
variable "allocated_storage" { type = number default = 50 }
variable "backup_retention_days" { type = number default = 7 }
variable "skip_final_snapshot" { type = bool default = true }
variable "deletion_protection" { type = bool default = false }
variable "tags" { type = map(string) default = {} }
