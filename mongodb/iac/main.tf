provider "aws" {
  region = "ap-east-1"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionMongodb"

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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_ssm_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# task definitions

resource "aws_ecs_task_definition" "mongodb" {
  family                   = "mongodb-replica-set"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode(flatten([
    [
      #master
      {
        name      = "mongodb",
        image     = var.mongodb_image,
        essential = true

        #   dependsOn = [
        #     {
        #       containerName = "init"
        #       condition     = "START"
        #     }
        #   ]
        environment = [
          {
            name  = "MONGO_INITDB_ROOT_USERNAME",
            value = var.mongodb_root_admin
            }, {
            name  = "MONGO_INITDB_ROOT_PASSWORD",
            value = var.mongodb_root_pass
            }, {
            name  = "REPLICA_SET_NAME",
            value = var.replica_set_name
            }, {
            name  = "SERVICE_DISCOVERY_NAMESPACE",
            value = local.mongodb_service_discovery_ns
          }
        ]

        portMappings = [
          {
            containerPort : 27017,
            hostPort : 27017,
            protocol = "tcp"
          }
        ]

        mountPoints = [{
          sourceVolume  = "efs-storage",
          containerPath = "/data/db/master",
          readOnly      = false
        }]

        healthCheck = {
          command     = ["CMD-SHELL", "mongo --eval 'db.adminCommand(\"ping\")' || exit 1"]
          internal    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 60
        }

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.mongodb_logs.name
            awslogs-region        = "ap-east-1"
            awslogs-stream-prefix = "mongodb"
          }
        }
    }],

    #slaves
    [for i in range(var.mongo_replicas) : {

      name      = "mongodb-slave-${i + 1}",
      image     = var.mongodb_image,
      essential = true

      #   dependsOn = [
      #     {
      #       containerName = "init"
      #       condition     = "START"
      #     }
      #   ]
      environment = [
        {
          name  = "MONGO_INITDB_ROOT_USERNAME",
          value = var.mongodb_root_admin
          }, {
          name  = "MONGO_INITDB_ROOT_PASSWORD",
          value = var.mongodb_root_pass
          }, {
          name  = "REPLICA_SET_NAME",
          value = var.replica_set_name
          }, {
          name  = "SERVICE_DISCOVERY_NAMESPACE",
          value = local.mongodb_service_discovery_ns
        }
      ]

      portMappings = [
        {
          containerPort : 27018 + i,
          hostPort : 27018 + i,
          protocol = "tcp"
        }
      ]

      mountPoints = [{
        sourceVolume  = "efs-storage",
        containerPath = "/data/db/slave${i + 1}",
        readOnly      = false
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "mongo --eval 'db.adminCommand(\"ping\")' || exit 1"]
        internal    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.mongodb_logs.name
          awslogs-region        = "ap-east-1"
          awslogs-stream-prefix = "mongodb-slave-${i}"
        }
      }
    }]
    #   , {
    #   name      = "init"
    #   image     = "busybox"
    #   command   = ["sh", "-c", "until [ ! -f /data/db/mongod.lock ]; do echo 'Waiting for MongoDB to release lock....'; sleep 5; done; echo 'Lock released.';"]
    #   essential = true
    # }

  ]))

  volume {
    name = "efs-storage"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.mongodb_efs.id
    }
  }
}

resource "aws_cloudwatch_log_group" "mongodb_logs" {
  name              = "/ecs/mongodb-logs"
  retention_in_days = 7
}

# primary service

resource "aws_ecs_service" "mongodb_primary" {
  name            = "mongodb-primary"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.mongodb.arn
  desired_count   = var.master_number
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.mongodb_sg.id]
    assign_public_ip = false
  }

  enable_execute_command = true
  service_registries {
    registry_arn = aws_service_discovery_service.mongodb_ds.arn
  }

  depends_on = [aws_service_discovery_service.mongodb_ds]
}

# secondary service

resource "aws_ecs_service" "mongodb_secondary" {
  name            = "mongodb-secondary"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.mongodb.arn
  desired_count   = var.mongo_replicas
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.mongodb_sg.id]
    assign_public_ip = false
  }

  enable_execute_command = true

  service_registries {
    registry_arn = aws_service_discovery_service.mongodb_ds.arn
  }

  depends_on = [aws_service_discovery_service.mongodb_ds]
}

# service ns

locals {
  mongodb_service_discovery_ns = aws_service_discovery_private_dns_namespace.mongodb_ns.name
}
# create efs

resource "aws_efs_file_system" "mongodb_efs" {
  creation_token   = "mongdb-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags = {
    Name = "mongodb-efs"
  }
}

# mount efs

resource "aws_efs_mount_target" "efs_mount" {
  for_each        = toset(var.private_subnets)
  file_system_id  = aws_efs_file_system.mongodb_efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_mongodb_sg.id]
}

resource "aws_efs_access_point" "mongodb_access_point" {
  file_system_id = aws_efs_file_system.mongodb_efs.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/mongodb-data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }
}

resource "aws_security_group" "efs_mongodb_sg" {
  name        = "efs_mongodb_sg"
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

resource "aws_security_group" "mongodb_sg" {
  name        = "mongodb-sg"
  description = "Allow Mongodb communication"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
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

# create discovery service

resource "aws_service_discovery_private_dns_namespace" "mongodb_ns" {
  name = var.service_discovery_ns
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "mongodb_ds" {
  name = "mongodb"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.mongodb_ns.id
    dns_records {
      type = "A"
      ttl  = 60
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
