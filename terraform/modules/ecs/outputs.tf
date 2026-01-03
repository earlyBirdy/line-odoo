output "cluster_name" { value = aws_ecs_cluster.this.name }
output "backend_service_name" { value = aws_ecs_service.backend.name }
output "odoo_service_name" { value = aws_ecs_service.odoo.name }
