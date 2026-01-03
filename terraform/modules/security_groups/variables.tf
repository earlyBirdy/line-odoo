variable "name" { type = string }
variable "vpc_id" { type = string }
variable "alb_ingress_cidrs" { type = list(string) default = ["0.0.0.0/0"] }
variable "enable_https" { type = bool default = false }
variable "tags" { type = map(string) default = {} }
