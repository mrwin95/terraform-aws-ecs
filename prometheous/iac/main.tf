provider "aws" {
  region = "ap-east-1"
}

#task execution role
resource "aws_iam_role" "ecs_task_execution_pro_role" {
  name = "ecsTaskExecutionRoleForPrometheus"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# create discovery policy
resource "aws_iam_policy" "ec2_discovery_policy" {
  name        = "EC2DiscoveryPolicy"
  description = "IAM policy for Prometheus EC2 service discovery"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "remote_container_policy" {
  name        = "ContainerRemotePolicy"
  description = "IAM policy for Prometheus container remote"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:ExecuteCommand",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# attacth to role

resource "aws_iam_role_policy_attachment" "attach_ec2_discovery_policy" {
  role       = aws_iam_role.ecs_task_execution_pro_role.name
  policy_arn = aws_iam_policy.ec2_discovery_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_remote_container_policy" {
  role       = aws_iam_role.ecs_task_execution_pro_role.name
  policy_arn = aws_iam_policy.remote_container_policy.arn
}

resource "aws_iam_policy_attachment" "ecs_task_execution_policy" {
  name       = "ecs_task_execution_policy"
  roles      = [aws_iam_role.ecs_task_execution_pro_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy_attachment" "ecs_ssm_policy" {
  name       = "ecs_ssm_policy"
  roles      = [aws_iam_role.ecs_task_execution_pro_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# cloudwatch logs
resource "aws_cloudwatch_log_group" "prometheus_log_group" {
  name              = "/ecs/prometheus-logs"
  retention_in_days = 7
}

# task definition
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024

  execution_role_arn = aws_iam_role.ecs_task_execution_pro_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_pro_role.arn
  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = var.prometheus_image
      cpu       = 512
      memory    = 1024
      essential = true

      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "sh -c 'nc -z localhost 9090 || exit 1'"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.prometheus_log_group.name
          awslogs-region        = "ap-east-1"
          awslogs-stream-prefix = "prometheus"
        }
      }
    }
    ]
  )
}

# target group

# resource "aws_alb_target_group" "prometheus-tg" {
#   name     = "prometheus-target-group"
#   port     = 9090
#   protocol = "HTTP"

#   health_check {
#     path                = "/"
#     interval            = 3
#     timeout             = 3
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     matcher             = "200-299"
#   }

#   vpc_id      = "vpc-067fa0610e0274258"
#   depends_on  = [aws_alb.grafana_alb]
#   target_type = "ip"
# }

# resource "aws_alb_listener" "prometheus_listener" {
#   port              = 9090
#   protocol          = "HTTP"
#   load_balancer_arn = aws_alb.grafana_alb.arn
#   default_action {
#     target_group_arn = aws_alb_target_group.prometheus-tg.arn
#     type             = "forward"
#   }
# }

# security group
resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus-sg"
  description = "Allow access to Prometheus"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# service

resource "aws_ecs_service" "prometheus_service" {
  name            = "prometheus-service"
  cluster         = aws_ecs_cluster.prometheus_cluster.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = var.prometheus_desired_count

  network_configuration {
    subnets          = toset(var.private_subnets)
    security_groups  = [aws_security_group.prometheus_sg.id]
    assign_public_ip = false
  }


  enable_execute_command = true

  launch_type = "FARGATE"

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus_service.arn
  }

  depends_on = [aws_service_discovery_service.prometheus_service]
}

resource "aws_ecs_cluster" "prometheus_cluster" {
  name = "prometheus-cluster"
}

# cloudwatch logs
resource "aws_cloudwatch_log_group" "grafana_log_group" {
  name              = "/ecs/grafana-logs"
  retention_in_days = 7
}


# task grafana

resource "aws_ecs_task_definition" "grafana_task" {
  family                   = "grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = var.grafana_image
      cpu       = 512
      memory    = 1024
      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = var.grafana_password
        }
      ]

      healthCheck = {
        command  = ["CMD-SHELL", "sh -c 'nc -z localhost 3000 || exit 1'"]
        interval = 30
        timeout  = 5
        retries  = 3
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.grafana_log_group.name
          awslogs-region        = "ap-east-1"
          awslogs-stream-prefix = "grafana"
        }
      }
    }
  ])

  execution_role_arn = aws_iam_role.ecs_task_execution_pro_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_pro_role.arn
}

#grafana service

resource "aws_ecs_service" "grafana_service" {
  name            = "grafana-service"
  cluster         = aws_ecs_cluster.prometheus_cluster.id
  task_definition = aws_ecs_task_definition.grafana_task.arn
  launch_type     = "FARGATE"
  desired_count   = var.grafana_desired_count

  enable_execute_command = true
  network_configuration {
    subnets          = toset(var.private_subnets)
    security_groups  = [aws_security_group.grafana_sg.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.grafana_service.arn
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana_tg.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.http_listener, aws_lb_listener.https_listener, aws_service_discovery_service.grafana_service]
}

# create a ALB

resource "aws_alb" "grafana_alb" {
  name                       = "grafana-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.grafana_sg.id]
  subnets                    = toset(var.public_subnets)
  enable_deletion_protection = false
}

# target group grafana

resource "aws_lb_target_group" "grafana_tg" {
  name     = "grafana-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
    port                = 3000
  }

  target_type = "ip"
  depends_on  = [aws_alb.grafana_alb]
}

# create SSL certificate in ACM

# resource "aws_acm_certificate" "grafana_ssl" {
#   domain_name       = var.domain_name
#   validation_method = "DNS"
#   tags = {
#     Name = "Grafana-SSL-Certificate"
#   }
# }
# listener

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_alb.grafana_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_alb.grafana_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }
}

# DNS setup

# resource "aws_route53_record" "grafana" {
#   zone_id = var.zone_id
#   name    = var.route53_record
#   type    = "A"

#   alias {
#     name                   = aws_alb.grafana_alb.dns_name
#     zone_id                = var.zone_id
#     evaluate_target_health = true
#   }
# }

# create rule

resource "aws_lb_listener_rule" "rule80" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }

  condition {
    host_header {
      values = [var.route53_record]
    }
  }

  tags = {
    Name = var.route53_record
  }
}

resource "aws_lb_listener_rule" "rule443" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }

  condition {
    host_header {
      values = [var.route53_record]
    }
  }

  tags = {
    Name = var.route53_record
  }
}
# security group

# resource "aws_security_group" "grafana_alb_sg" {
#   name        = "grafana-alb-sg"
#   description = "Security group for Grafana ALB"

#   ingress = [{
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     }, {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }]

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   vpc_id = var.vpc_id
# }

resource "aws_security_group" "grafana_sg" {
  name        = "grafana-sg"
  description = "grafana-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = var.vpc_id
}

# create private namespace

resource "aws_service_discovery_private_dns_namespace" "monitoring_ns" {
  name        = "samteh.local"
  description = "Private DNS ns for ECS services"
  vpc         = var.vpc_id
}

# dns for prometheus
resource "aws_service_discovery_service" "prometheus_service" {
  name = "prometheus"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring_ns.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# dns for prometheus
resource "aws_service_discovery_service" "grafana_service" {
  name = "grafana"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring_ns.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
