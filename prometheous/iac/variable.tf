variable "vpc_id" {}

variable "prometheus_image" {}
variable "grafana_image" {}
variable "private_subnets" {
  type = set(string)
}
variable "grafana_password" {

}
variable "public_subnets" {
  type = set(string)
}
variable "grafana_desired_count" {
  type = number
}
variable "prometheus_desired_count" {
  type = number
}
