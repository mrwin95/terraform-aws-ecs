resource "aws_ecs_service" "this" {
  name        = var.name
  cluster     = var.cluster_name
  launch_type = "EC2"

  task_definition = aws_ecs_task_definition.this.arn

  force_new_deployment = false
  desired_count        = var.desired_count

  dynamic "load_balancer" {
    for_each = var.create_lb ? aws_lb_target_group.this : []
    content {
      target_group_arn = load_balancer.value.arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  network_configuration {
    subnets          = toset(var.private_subnets)
    security_groups  = [aws_security_group.mongodb_sg.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.mongodb_sv.arn
  }
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
}
