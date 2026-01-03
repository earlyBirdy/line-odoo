variable "name" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "sg_redis_id" { type = string }
variable "node_type" { type = string default = "cache.t4g.micro" }
variable "tags" { type = map(string) default = {} }
