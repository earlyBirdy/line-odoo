locals {
  name = "dev-line-odoo"
  tags = {
    Project     = "line-odoo"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
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
  sg_alb_id         = module.sg.sg_alb_id
  tags              = local.tags
}

module "iam" {
  source      = "../../modules/iam"
  name        = local.name
  secret_arns = var.secret_arns
  tags        = local.tags
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

output "alb_dns_name" { value = module.alb.alb_dns_name }
output "db_endpoint"  { value = module.rds.db_endpoint }
output "redis_endpoint" { value = module.redis.redis_endpoint }
