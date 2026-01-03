output "alb_arn" { value = aws_lb.this.arn }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "tg_backend_arn" { value = aws_lb_target_group.backend.arn }
output "tg_odoo_arn" { value = aws_lb_target_group.odoo.arn }
output "listener_http_arn" { value = aws_lb_listener.http.arn }
