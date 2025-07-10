# Create ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster-${var.region}"

  tags = {
    Name = "${var.app_name}-cluster-${var.region}"
  }
}

# Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.app_name}-${var.region}"
  retention_in_days = 1

  tags = {
    Name = "${var.app_name}-log-group-${var.region}"
  }
}

# For LocalStack, we'll use a public image instead of ECR
# ECR repository creation commented out for simplicity
# resource "aws_ecr_repository" "main" {
#   name                 = "${var.app_name}-${var.region}"
#   image_tag_mutability = "MUTABLE"
#
#   tags = {
#     Name = "${var.app_name}-ecr-${var.region}"
#   }
# }

# Create ECS task execution role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.app_name}-ecs-task-execution-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-ecs-task-execution-${var.region}"
  }
}

# Attach required policies to execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution.name
}

# Create ECS task definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.app_name}-${var.region}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = var.app_name
      image = "nginx:alpine"  # Using public nginx image for LocalStack
      
      environment = [
        {
          name  = "REGION"
          value = var.region
        }
      ]

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.main.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "${var.app_name}-task-${var.region}"
  }
}

# Create ECS service
resource "aws_ecs_service" "main" {
  name            = "${var.app_name}-service-${var.region}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy_attachment.ecs_task_execution
  ]

  tags = {
    Name = "${var.app_name}-service-${var.region}"
  }
}