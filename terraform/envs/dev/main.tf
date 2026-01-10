locals {
  name = "dev-line-odoo"
  tags = {
    Project     = "line-odoo"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}



module "alb_logs" {
  source                = "../../modules/s3_logs"
  name                  = local.name
  bucket_name           = "${local.name}-dev-alb-logs"
  enable_alb_log_delivery = true
  force_destroy         = var.force_destroy_log_bucket
  tags                  = local.tags
encryption_mode        = "SSE-S3"
deny_unencrypted_puts  = false
kms_alias_suffix       = "alb-logs"
}


module "waf_logs" {
  source        = "../../modules/s3_logs"
  name          = local.name
  bucket_name   = "${local.name}-dev-waf-logs"
  enable_alb_log_delivery = false
  force_destroy = var.force_destroy_log_bucket
  tags          = local.tags
  encryption_mode       = "SSE-KMS"
  deny_unencrypted_puts = true
  # KMS key is created separately with a policy pinned to this env's Firehose stream/role.
  kms_key_arn           = module.waf_kms.kms_key_arn
  kms_alias_suffix      = "waf-logs"
}

module "waf_kms" {
  source              = "../../modules/kms_firehose_s3"
  name                = local.name
  tags                = local.tags
  bucket_name         = "${local.name}-dev-waf-logs"
  s3_prefix           = var.waf_log_prefix
  firehose_stream_name = "${local.name}-waf-logs"
  delivery_role_name  = "${local.name}-waf-firehose-role"
  kms_alias_suffix    = "waf-logs"
}


module "acm" {
  source           = "../../modules/acm_route53"
  name             = local.name
  hosted_zone_name = var.hosted_zone_name
  domains          = [var.domain_api, var.domain_odoo]
  tags             = local.tags
}

module "vpc" {
  source     = "../../modules/vpc"
  name       = local.name
  vpc_cidr   = var.vpc_cidr
  az_count   = var.az_count
  enable_nat = true
  tags       = local.tags
}

module "sg" {
  source            = "../../modules/security_groups"
  name              = local.name
  vpc_id            = module.vpc.vpc_id
  alb_ingress_cidrs = var.alb_ingress_cidrs
  enable_https      = var.enable_https
  tags              = local.tags
}

module "logs" {
  source         = "../../modules/logs"
  name           = local.name
  retention_days = var.log_retention_days
  tags           = local.tags
}

module "efs" {
  source             = "../../modules/efs"
  name               = local.name
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_efs_id          = module.sg.sg_efs_id
  tags               = local.tags
}

module "rds" {
  source             = "../../modules/rds"
  name               = local.name
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_rds_id          = module.sg.sg_rds_id
  db_username        = var.db_username
  db_password        = var.db_password
  db_name            = var.db_name
  instance_class     = var.db_instance_class
  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection
  tags               = local.tags
}

module "redis" {
  source             = "../../modules/redis"
  name               = local.name
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_redis_id        = module.sg.sg_redis_id
  node_type          = var.redis_node_type
  tags               = local.tags
}

module "alb" {
  source            = "../../modules/alb"
  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.sg.sg_alb_id
  acm_certificate_arn = module.acm.certificate_arn
  tags              = local.tags
  enable_access_logs = true
  access_logs_bucket = module.alb_logs.bucket_name
  access_logs_prefix = var.alb_log_prefix
}

module "waf" {
  source = "../../modules/waf"
  name   = local.name
  alb_arn = module.alb.alb_arn
  webhook_path = var.waf_webhook_path
  webhook_rate_limit = var.waf_webhook_rate_limit
  tags   = local.tags
  log_bucket_arn  = module.waf_logs.bucket_arn
  log_bucket_name = module.waf_logs.bucket_name
  log_prefix      = var.waf_log_prefix
  redact_headers        = var.waf_redact_headers
  redact_query_string   = var.waf_redact_query_string
  redact_uri_path       = var.waf_redact_uri_path
  redact_method         = var.waf_redact_method

  # Use the dedicated CMK pinned to this env's Firehose delivery role/stream.
  log_bucket_kms_key_arn = module.waf_kms.kms_key_arn
  create_kms_key         = false
}


module "iam" {
  source      = "../../modules/iam"
  name        = local.name
  secret_arns = var.secret_arns
  tags        = local.tags
}


module "github_oidc" {
  source            = "../../modules/github_oidc"
  role_name         = var.github_oidc_role_name
  github_org        = var.github_org
  github_repo       = var.github_repo
  github_branch     = var.github_branch
  tf_state_bucket   = var.tf_state_bucket
  tf_lock_table_arn = var.tf_lock_table_arn
  tags              = local.tags
}

module "ecs" {
  source                 = "../../modules/ecs"
  name                   = local.name
  aws_region             = var.aws_region
  private_subnet_ids      = module.vpc.private_subnet_ids
  sg_ecs_id              = module.sg.sg_ecs_id
  task_execution_role_arn = module.iam.task_execution_role_arn
  backend_task_role_arn    = module.iam.backend_task_role_arn
  odoo_task_role_arn       = module.iam.odoo_task_role_arn

  backend_image          = var.backend_image
  odoo_image             = var.odoo_image
  backend_env            = var.backend_env
  odoo_env               = var.odoo_env

  backend_log_group      = module.logs.backend_log_group
  odoo_log_group         = module.logs.odoo_log_group

  efs_id                 = module.efs.efs_id

  tg_backend_arn         = module.alb.tg_backend_arn
  tg_odoo_arn            = module.alb.tg_odoo_arn
  listener_http_arn      = module.alb.listener_http_arn

  desired_count          = var.desired_count
  tags                   = local.tags
}


module "route53_alias" {
  source         = "../../modules/route53_alias"
  hosted_zone_id = module.acm.hosted_zone_id
  records = var.create_route53_alias_records ? [
    { name = var.domain_api,  alb_dns_name = module.alb.alb_dns_name, alb_zone_id = module.alb.alb_zone_id },
    { name = var.domain_odoo, alb_dns_name = module.alb.alb_dns_name,      alb_zone_id = module.alb.alb_zone_id }
  ] : []
  tags = local.tags
}

output "alb_dns_name" { value = module.alb.alb_dns_name }
output "db_endpoint"  { value = module.rds.db_endpoint }
output "redis_endpoint" { value = module.redis.redis_endpoint }
