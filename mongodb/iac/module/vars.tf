variable "name" {}
variable "cluster_name" {}
variable "mongodb_image" {}
variable "container_port" {}
variable "environment" {}
variable "mount_points" {
  default = null
}
variable "volumes" {
  default = null
}
variable "placementConstraints" {}
variable "discovery_namespace_id" {}
variable "security_groups" {}
variable "private_subnets" {
  type = list(string)
}
variable "task_role_arn" {}
variable "execution_role_arn" {}
variable "memory" {}
variable "desired_count" {
  default = 1
}
variable "create_lb" {
  default = false
}
variable "lb_arn" {
  default = null
}
variable "listener_port" {
  default = null
}
variable "log_group_name" {

}

# variable "service_name" {

# }

# variable "container_name" {

# }
