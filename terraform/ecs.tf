# Phase 8: ECS Fargate replaces the Phase 7 ASG. Same "app" SG reused (already trusted by RDS SG),
# plus a self-referencing rule so customer-service can reach movie-service over Service Connect DNS.

resource "aws_security_group_rule" "app_self" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.app.id
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "${var.project_name}.local"
  vpc  = aws_vpc.main.id
}

resource "aws_cloudwatch_log_group" "movie_service" {
  name              = "/ecs/${var.project_name}/movie-service"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "customer_service" {
  name              = "/ecs/${var.project_name}/customer-service"
  retention_in_days = 7
}

# Execution role: pulls image from ECR, ships logs to CloudWatch. Not used to fetch app secrets.
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: assumed by the running app itself, needs read on the two DB secrets only.
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "${var.project_name}-ecs-task-secrets"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = [
        aws_secretsmanager_secret.db_customer.arn,
        aws_secretsmanager_secret.db_movie.arn,
      ]
    }]
  })
}

resource "aws_ecs_task_definition" "movie_service" {
  family                   = "${var.project_name}-movie-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "movie-service"
    image = "${aws_ecr_repository.movie_service.repository_url}:latest"
    portMappings = [{ name = "movie-service-port", containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = "prod" },
      { name = "AWS_REGION", value = var.aws_region },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.movie_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "movie-service"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "customer_service" {
  family                   = "${var.project_name}-customer-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "customer-service"
    image = "${aws_ecr_repository.customer_service.repository_url}:latest"
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = "prod" },
      { name = "AWS_REGION", value = var.aws_region },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.customer_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "customer-service"
      }
    }
  }])
}

resource "aws_ecs_service" "movie_service" {
  name            = "movie-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.movie_service.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.internal.arn

    service {
      port_name      = "movie-service-port"
      discovery_name = "movie-service"
      client_alias {
        port     = 8080
        dns_name = "movie-service"
      }
    }
  }
}

resource "aws_ecs_service" "customer_service" {
  name            = "customer-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.customer_service.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  # App takes ~100-120s to boot (Secrets Manager fetch + Spring context init) — without this,
  # the ALB health check marks it unhealthy before boot finishes and ECS cycles it forever.
  health_check_grace_period_seconds = 180

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.customer_service.arn
    container_name   = "customer-service"
    container_port   = 8080
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.internal.arn
  }

  depends_on = [aws_lb_listener.http]
}
