provider "aws" {
  region = "ap-east-1"
}
# data "aws_subnets" "all" {
#   filter {
#     name   = "vpc-id"
#     values = [var.vpc_id]
#   }
# }
resource "aws_efs_file_system" "redis_efs" {
  creation_token   = "redis-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "redis-efs"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "efs_sg"
  description = "efs sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
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

resource "aws_efs_mount_target" "redis_mount" {
  for_each        = toset(var.subnets)
  file_system_id  = aws_efs_file_system.redis_efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_sg.id]

  #   lifecycle {
  #     ignore_changes = [availability_zone_id]
  #   }
}

resource "aws_efs_access_point" "redis_access_point" {
  file_system_id = aws_efs_file_system.redis_efs.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/redis-data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRoleRedis"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Action" : "sts:AssumeRole",
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "ecs-tasks.amazonaws.com"
      }
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRoleRedis"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Action" : "sts:AssumeRole",
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_cloudwatch_log_group" "redis_log_group" {
  name              = "/ecs/redis-logs"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "redis_master" {
  family                   = "redis-master"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "redis-master"
    image     = var.image
    essential = true
    portMappings = [{
      containerPort = 6379
      hostPort      = 6379
      protocol      = "tcp"
    }]

    healthCheck = {
      command     = ["CMD-SHELL", "redis-cli ping || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.redis_log_group.name
        awslogs-region        = "ap-east-1"
        awslogs-stream-prefix = "redis-master-prod"
      }
    }

    mountPoints = [{
      sourceVolume  = "efs"
      containerPath = "/data"
    }]

    environment = [{
      name = "REDIS_REPLICATION_MODE", value = "master"
    }]

  }])

  volume {
    name = "efs"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.redis_efs.id
    }
  }
}

resource "aws_ecs_task_definition" "redis_slave" {
  family                   = "redis-slave"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "redis-slave"
    image     = var.slave_image
    essential = true
    portMappings = [{
      containerPort = 6379
      hostPort      = 6379
      protocol      = "tcp"
    }]

    mountPoints = [{
      sourceVolume  = "efs"
      containerPath = "/data"
    }]

    healthCheck = {
      command     = ["CMD-SHELL", "redis-cli ping || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.redis_log_group.name
        awslogs-region        = "ap-east-1"
        awslogs-stream-prefix = "redis-slave-prod"
      }
    }

    environment = [{
      name = "REDIS_REPLICATION_MODE", value = "slave"
      },
      {
        name = "REDIS_MASTER_HOST", value = local.redis_master_dns_name
      },
      {
        name = "REDIS_PORT", value = "6379"
    }]

    #command = ["redis-server", "--replicaof", "$REDIS_MASTER_HOST", "6379"]
  }])

  volume {
    name = "efs"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.redis_efs.id
    }
  }
}

resource "aws_ecs_service" "redis_master" {
  name            = "redis-master-service"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.redis_master.arn
  desired_count   = 0
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [var.subnet_public_1, var.subnet_public_2]
    security_groups  = [aws_security_group.redis_sg.id]
    assign_public_ip = true
  }

  enable_execute_command = true
  service_registries {
    registry_arn = aws_service_discovery_service.redis_master_service.arn
  }

  depends_on = [aws_service_discovery_service.redis_master_service]
}

resource "aws_ecs_service" "redis_slave" {
  name            = "redis-slave-service"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.redis_slave.arn
  desired_count   = 0
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [var.subnet_public_1, var.subnet_public_2]
    security_groups  = [aws_security_group.redis_sg.id]
    assign_public_ip = true
  }

  enable_execute_command = true

  service_registries {
    registry_arn = aws_service_discovery_service.redis_slave_service.arn
  }

  depends_on = [aws_service_discovery_service.redis_slave_service]
}

resource "aws_security_group" "redis_sg" {
  name        = "redis_sg"
  description = "Redis SG"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 6379
    to_port     = 6379
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

# constructing the full dns name

locals {
  redis_master_dns_name = "${aws_service_discovery_service.redis_master_service.name}.${aws_service_discovery_private_dns_namespace.redis_namespace.name}"
}

resource "aws_service_discovery_private_dns_namespace" "redis_namespace" {
  name        = "redis.local"
  description = "redis local dns"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "redis_master_service" {
  name = "redis-master"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.redis_namespace.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "redis_slave_service" {
  name = "redis-slave"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.redis_namespace.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

