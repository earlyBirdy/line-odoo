resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  access_logs {
    enabled = var.enable_access_logs
    bucket  = var.access_logs_bucket
    prefix  = var.access_logs_prefix
  }

  tags               = var.tags
}


resource "aws_lb_target_group" "backend" {
  name        = "${var.name}-tg-backend"
  port        = var.backend_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.backend_health_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200-399"
  }

  tags = var.tags
}

resource "aws_lb_target_group" "odoo" {
  name        = "${var.name}-tg-odoo"
  port        = var.odoo_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.odoo_health_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200-399"
  }

  tags = var.tags
}

# HTTP -> HTTPS redirect (enforcement)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener (requires ACM cert)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Route to backend by default; optionally refine by path rules
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = var.backend_path_patterns
    }
  }
}

resource "aws_lb_listener_rule" "odoo" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.odoo.arn
  }

  condition {
    path_pattern {
      values = var.odoo_path_patterns
    }
  }
}

output "alb_arn" { value = aws_lb.this.arn }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "tg_backend_arn" { value = aws_lb_target_group.backend.arn }
output "tg_odoo_arn" { value = aws_lb_target_group.odoo.arn }
output "listener_http_arn" { value = aws_lb_listener.http.arn }
output "listener_https_arn" { value = aws_lb_listener.https.arn }

output "alb_zone_id" { value = aws_lb.this.zone_id }
