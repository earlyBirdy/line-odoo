# Central security groups for ALB, ECS tasks, RDS, Redis, EFS
resource "aws_security_group" "alb" {
  name        = "${var.name}-sg-alb"
  description = "ALB ingress"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-sg-alb" })
}

resource "aws_security_group_rule" "alb_in_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.alb_ingress_cidrs
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_in_https" {
  count             = var.enable_https ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.alb_ingress_cidrs
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_out_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-sg-ecs"
  description = "ECS tasks"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-sg-ecs" })
}

resource "aws_security_group_rule" "ecs_in_from_alb" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "ecs_out_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-sg-rds"
  description = "Postgres"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-sg-rds" })
}

resource "aws_security_group_rule" "rds_in_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_out_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-sg-redis"
  description = "Redis"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-sg-redis" })
}

resource "aws_security_group_rule" "redis_in_from_ecs" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  security_group_id        = aws_security_group.redis.id
}

resource "aws_security_group_rule" "redis_out_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.redis.id
}

resource "aws_security_group" "efs" {
  name        = "${var.name}-sg-efs"
  description = "EFS"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-sg-efs" })
}

resource "aws_security_group_rule" "efs_in_from_ecs" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  security_group_id        = aws_security_group.efs.id
}

resource "aws_security_group_rule" "efs_out_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs.id
}
