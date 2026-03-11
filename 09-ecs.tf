# The ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ------------------------------------------------------------------------------
# Capacity Provider (The SRE secret to safe Spot instances)
# ------------------------------------------------------------------------------

resource "aws_ecs_capacity_provider" "spot" {
  name = "${var.project_name}-spot-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.spot.name]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.spot.name
  }
}

# ------------------------------------------------------------------------------
# Task Definitions (Defining your Docker images)
# ------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "frontend" {
  family             = "${var.project_name}-frontend"
  network_mode       = "bridge"
  execution_role_arn = aws_iam_role.ecs_node_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend-container"
      image     = "kabilarajah/weather-frontend:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 0 # Dynamic port mapping
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "backend" {
  family             = "${var.project_name}-backend"
  network_mode       = "bridge"
  execution_role_arn = aws_iam_role.ecs_node_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend-container"
      image     = "kabilarajah/weather-backend:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 0 # Dynamic port mapping
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ------------------------------------------------------------------------------
# ECS Services (Keeping the containers running)
# ------------------------------------------------------------------------------

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2 # Run two copies for high availability

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.spot.name
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend-container"
    container_port   = 80
  }

  # Allow external changes to task definition without Terraform fighting it
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.spot.name
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend-container"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}