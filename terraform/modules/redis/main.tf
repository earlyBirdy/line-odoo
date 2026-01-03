resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.name}-redis"
  engine               = "redis"
  node_type            = var.node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [var.sg_redis_id]
  tags                 = var.tags
}
