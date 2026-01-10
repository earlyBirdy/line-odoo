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

# --- HTTPS / ACM ---
acm_certificate_arn = "arn:aws:acm:REGION:ACCOUNT:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# --- GitHub OIDC ---
github_oidc_role_name = "prod-line-odoo-gh-terraform-role"
github_org = "YOUR_GITHUB_ORG"
github_repo = "YOUR_GITHUB_REPO"
github_branch = "main"

# Remote state (must match backend.tf)
tf_state_bucket = "your-tfstate-bucket-name"
tf_lock_table_arn = "arn:aws:dynamodb:REGION:ACCOUNT:table/your-tf-lock-table"

# --- WAF ---
waf_webhook_path = "/line/webhook"
waf_webhook_rate_limit = 300

hosted_zone_name = "example.com."

domain_api = "api.example.com"

domain_odoo = "odoo.example.com"

create_route53_alias_records = true

waf_log_prefix = "waf/prod"

alb_log_prefix = "alb/prod"

force_destroy_log_bucket = false
