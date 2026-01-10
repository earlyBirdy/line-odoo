variable "name" { type = string }

variable "hosted_zone_name" {
  type        = string
  description = "Route53 hosted zone name (e.g., example.com.)."
}

variable "domains" {
  type        = list(string)
  description = "List of FQDNs. First is primary domain_name, rest are SANs."
}

variable "tags" { type = map(string) default = {} }
