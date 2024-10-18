resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  memory                   = var.memory
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.ecs_task_execution_mongodb_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_mongodb_role.arn
  network_mode             = "awsvpc"

  dynamic "volume" {
    for_each = var.volumes == null ? [] : var.volumes
    content {
      name      = volume.value.name
      host_path = try(volume.value.host_path, null)
      dynamic "docker_volume_configuration" {
        for_each = can(volume.value.docker_volume_configuration) ? [try(volume.value.docker_volume_configuration, {})] : []
        content {
          scope         = try(docker_volume_configuration.value.scope, null)
          autoprovision = try(docker_volume_configuration.value.autoprovision, null)
          driver        = try(docker_volume_configuration.value.driver, null)
        }
      }
    }
  }

  container_definitions = jsonencode([
    {
      name  = "mongodb",
      image = var.mongodb_image,
      portMappings = [
        {
          containerPort = var.container_port,
        }
      ],
      "environment" : var.environment,
      "mountPoints" : var.mount_points,
      "placementConstraints" : var.placementConstraints,
      "volumes" : var.volumes,
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-create-group" : "true",
          "awslogs-group" : "/ecs/${var.log_group_name}",
          "awslogs-region" : data.aws_region.this.name,
          "awslogs-stream-prefix" : "ecs"
        }
      },
    }
  ])
}
