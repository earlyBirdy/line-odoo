resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
  tags = var.tags
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.backend_task_role_arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = var.backend_image
      portMappings = [{ containerPort = 8000, hostPort = 8000, protocol = "tcp" }]
      environment = var.backend_env
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = var.backend_log_group,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -fsS http://localhost:8000/health || exit 1"],
        interval    = 30,
        timeout     = 5,
        retries     = 3,
        startPeriod = 20
      }
    }
  ])
  tags = var.tags
}

resource "aws_ecs_task_definition" "odoo" {
  family                   = "${var.name}-odoo"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.odoo_cpu
  memory                   = var.odoo_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.odoo_task_role_arn

  volume {
    name = "odoo_filestore"
    efs_volume_configuration {
      file_system_id = var.efs_id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name  = "odoo"
      image = var.odoo_image
      portMappings = [{ containerPort = 8069, hostPort = 8069, protocol = "tcp" }]
      environment = var.odoo_env
      mountPoints = [{ sourceVolume = "odoo_filestore", containerPath = "/var/lib/odoo" }]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = var.odoo_log_group,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  tags = var.tags
}

resource "aws_ecs_service" "backend" {
  name            = "${var.name}-svc-backend"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_ecs_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.tg_backend_arn
    container_name   = "backend"
    container_port   = 8000
  }

  depends_on = [var.listener_http_arn]
  tags = var.tags
}

resource "aws_ecs_service" "odoo" {
  name            = "${var.name}-svc-odoo"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.odoo.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_ecs_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.tg_odoo_arn
    container_name   = "odoo"
    container_port   = 8069
  }

  depends_on = [var.listener_http_arn]
  tags = var.tags
}
