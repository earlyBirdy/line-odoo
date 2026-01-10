variable "hosted_zone_id" { type = string }
variable "records" {
  type = list(object({
    name         = string
    alb_dns_name = string
    alb_zone_id  = string
  }))
}
variable "tags" { type = map(string) default = {} }
