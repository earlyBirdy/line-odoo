variable "name" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "sg_efs_id" { type = string }
variable "tags" { type = map(string) default = {} }
