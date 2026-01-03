aws_region = "ap-southeast-1"
vpc_cidr   = "10.30.0.0/16"
az_count   = 2

alb_ingress_cidrs = ["0.0.0.0/0"]
enable_https      = false
log_retention_days = 30

db_username = "odoo"
db_password = "REPLACE_ME"
db_name     = "odoo"
db_instance_class = "db.t4g.medium"
skip_final_snapshot = true
deletion_protection = false

redis_node_type = "cache.t4g.micro"

# Set these to your ECR image URIs (or DockerHub if allowed)
backend_image = "REPLACE_ME_BACKEND_IMAGE"
odoo_image    = "REPLACE_ME_ODOO_IMAGE"

desired_count = 1

# Optional environment variables (examples)
backend_env = [
  { name = "ODDO_URL", value = "http://odoo:8069" }
]

odoo_env = [
  { name = "ODOO_DB_HOST", value = "REPLACE_ME_DB_HOST" }
]

secret_arns = []
