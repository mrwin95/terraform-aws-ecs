variable "region" {
  description = "ap-south-1"
}

variable "environment" {
  description = "The Deployment environment"
}

//Networking
variable "vpc_cidr" {
  description = "The CIDR block of the vpc"
}

variable "public_subnets_cidr" {
  type        = list(any)
  description = "The CIDR block for the public subnet"
}

variable "private_subnets_cidr" {
  type        = list(any)
  description = "The CIDR block for the private subnet"
}
variable "ami" {

}

variable "instance_type" {

}

variable "private_subnet_dc1" {

}

variable "private_subnet_dc2" {

}
variable "key_name" {

}

variable "computer_name_dc1" {

}
variable "computer_name_dc2" {

}

variable "domain_name" {

}

variable "safemode_password" {

}
