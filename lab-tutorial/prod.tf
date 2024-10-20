/*====
Variables used across all modules
======*/
locals {
  production_availability_zones = ["${var.region}a", "${var.region}b"]
}

module "networking" {
  source               = "./modules/networking"
  region               = var.region
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  availability_zones   = local.production_availability_zones
}

module "security_group" {
  source      = "./modules/sg"
  vpc_id      = module.networking.vpc_id
  cidr_blocks = var.vpc_cidr
}

# module "create_ec2_dc" {
#   source             = "./modules/ec2"
#   ami                = var.ami
#   instance_type      = var.instance_type
#   key_name           = var.key_name
#   private_subnet_dc1 = module.networking.private_subnet_1a
#   private_subnet_dc2 = module.networking.private_subnet_1b
#   security_group     = [module.security_group.security_group_id]
#   computer_name_dc1  = var.computer_name_dc1
#   computer_name_dc2  = var.computer_name_dc2
#   domain_name        = var.domain_name
#   safemode_password  = var.safemode_password
# }
