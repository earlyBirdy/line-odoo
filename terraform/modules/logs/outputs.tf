output "backend_log_group" { value = aws_cloudwatch_log_group.backend.name }
output "odoo_log_group" { value = aws_cloudwatch_log_group.odoo.name }
