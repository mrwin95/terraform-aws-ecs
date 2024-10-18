variable "vpc_id" {}
variable "mongodb_root_admin" {}
variable "mongodb_root_pass" {}
variable "replica_set_name" {}
variable "service_discovery_ns" {}
variable "mongodb_image" {}
variable "private_subnets" {
  type = set(string)
}
variable "cluster_name" {}
variable "mongo_replicas" {
  type    = number
  default = 2
}
variable "master_number" {

}
variable "service_name" {}
variable "desired_count" {

}
variable "create_lb" {

}
variable "container_name" {

}
variable "container_port" {

}

variable "family_name" {

}
variable "memory" {

}

variable "volumes" {


}

variable "mount_points" {

}

variable "environment" {

}

variable "placementConstraints" {

}

variable "log_group_name" {

}
