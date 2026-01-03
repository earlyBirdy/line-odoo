variable "name" { type = string }
variable "aws_region" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "sg_ecs_id" { type = string }
variable "task_execution_role_arn" { type = string }
variable "backend_task_role_arn" { type = string }
variable "odoo_task_role_arn" { type = string }

variable "backend_image" { type = string }
variable "odoo_image" { type = string }
variable "backend_env" { type = list(object({name=string,value=string})) default = [] }
variable "odoo_env" { type = list(object({name=string,value=string})) default = [] }

variable "backend_log_group" { type = string }
variable "odoo_log_group" { type = string }

variable "efs_id" { type = string }

variable "tg_backend_arn" { type = string }
variable "tg_odoo_arn" { type = string }
variable "listener_http_arn" { type = string }

variable "desired_count" { type = number default = 1 }
variable "backend_cpu" { type = number default = 512 }
variable "backend_memory" { type = number default = 1024 }
variable "odoo_cpu" { type = number default = 1024 }
variable "odoo_memory" { type = number default = 2048 }

variable "tags" { type = map(string) default = {} }
