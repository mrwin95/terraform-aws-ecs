variable "vpc_id" {}
variable "subnets" {
  type = set(string)
}
variable "image" {}
variable "slave_image" {}
variable "subnet_private_1" {}
variable "subnet_private_2" {}

variable "subnet_public_1" {}
variable "subnet_public_2" {}
variable "cluster_name" {}
