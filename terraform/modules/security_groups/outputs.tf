output "sg_alb_id" { value = aws_security_group.alb.id }
output "sg_ecs_id" { value = aws_security_group.ecs.id }
output "sg_rds_id" { value = aws_security_group.rds.id }
output "sg_redis_id" { value = aws_security_group.redis.id }
output "sg_efs_id" { value = aws_security_group.efs.id }
