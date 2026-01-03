variable "name" { type = string }
variable "secret_arns" { type = list(string) default = [] }
variable "tags" { type = map(string) default = {} }
