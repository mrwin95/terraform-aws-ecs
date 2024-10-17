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
