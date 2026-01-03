resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.name}/backend"
  retention_in_days = var.retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "odoo" {
  name              = "/ecs/${var.name}/odoo"
  retention_in_days = var.retention_days
  tags              = var.tags
}
