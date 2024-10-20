# provider "aws" {
#   region = "us-west-2"
# }

# # VPC, Subnets, and Internet Gateway
# resource "aws_vpc" "vpc" {
#   cidr_block           = "10.20.0.0/16"
#   enable_dns_support   = true
#   enable_dns_hostnames = true
# }

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.vpc.id
# }

# resource "aws_subnet" "public_subnet" {
#   vpc_id                  = aws_vpc.vpc.id
#   cidr_block              = "10.20.1.0/24"
#   availability_zone       = "us-west-2a"
#   map_public_ip_on_launch = true
# }

# resource "aws_subnet" "private_subnet" {
#   vpc_id                  = aws_vpc.vpc.id
#   cidr_block              = "10.20.2.0/24"
#   availability_zone       = "us-west-2b"
#   map_public_ip_on_launch = false
# }

# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public_subnet.id
# }

# resource "aws_eip" "nat" {
#   vpc = true
# }

# resource "aws_route_table" "public_rt" {
#   vpc_id = aws_vpc.vpc.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
# }

# resource "aws_route_table" "private_rt" {
#   vpc_id = aws_vpc.vpc.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat_gw.id
#   }
# }

# resource "aws_route_table_association" "public_rt_assoc" {
#   subnet_id      = aws_subnet.public_subnet.id
#   route_table_id = aws_route_table.public_rt.id
# }

# resource "aws_route_table_association" "private_rt_assoc" {
#   subnet_id      = aws_subnet.private_subnet.id
#   route_table_id = aws_route_table.private_rt.id
# }

# # Security Groups for Domain Controllers and Load Balancer
# resource "aws_security_group" "dc_sg" {
#   vpc_id = aws_vpc.vpc.id

#   ingress {
#     from_port   = 3389
#     to_port     = 3389
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 53
#     to_port     = 53
#     protocol    = "udp"
#     cidr_blocks = ["10.20.0.0/16"]
#   }

#   ingress {
#     from_port   = 53
#     to_port     = 53
#     protocol    = "tcp"
#     cidr_blocks = ["10.20.0.0/16"]
#   }

#   ingress {
#     from_port   = 135
#     to_port     = 135
#     protocol    = "tcp"
#     cidr_blocks = ["10.20.0.0/16"]
#   }

#   ingress {
#     from_port   = 389
#     to_port     = 389
#     protocol    = "tcp"
#     cidr_blocks = ["10.20.0.0/16"]
#   }

#   ingress {
#     from_port   = 636
#     to_port     = 636
#     protocol    = "tcp"
#     cidr_blocks = ["10.20.0.0/16"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "DC-Security-Group"
#   }
# }

# resource "aws_security_group" "lb_sg" {
#   vpc_id = aws_vpc.vpc.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "LB-Security-Group"
#   }
# }

# # EC2 Instances for DC1 and DC2
# resource "aws_instance" "dc1" {
#   ami                    = "ami-0c55b159cbfafe1f0"
#   instance_type          = "t3.medium"
#   subnet_id              = aws_subnet.private_subnet.id
#   key_name               = "your-key-pair"
#   vpc_security_group_ids = [aws_security_group.dc_sg.id]

#   user_data = <<EOF
# <powershell>
# Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
# Install-WindowsFeature -Name DNS -IncludeManagementTools
# </powershell>
# EOF

#   tags = {
#     Name = "DC1"
#   }
# }

# resource "aws_instance" "dc2" {
#   ami                    = "ami-0c55b159cbfafe1f0"
#   instance_type          = "t3.medium"
#   subnet_id              = aws_subnet.private_subnet.id
#   key_name               = "your-key-pair"
#   vpc_security_group_ids = [aws_security_group.dc_sg.id]

#   user_data = <<EOF
# <powershell>
# Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
# Install-WindowsFeature -Name DNS -IncludeManagementTools
# </powershell>
# EOF

#   tags = {
#     Name = "DC2"
#   }
# }

# # Application Load Balancer and Target Group
# resource "aws_lb" "app_lb" {
#   name               = "app-lb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.lb_sg.id]
#   subnets            = [aws_subnet.public_subnet.id]

#   enable_deletion_protection = false
#   tags = {
#     Name = "App-Load-Balancer"
#   }
# }

# resource "aws_lb_target_group" "app_tg" {
#   name     = "app-target-group"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.vpc.id

#   health_check {
#     interval            = 30
#     path                = "/"
#     protocol            = "HTTP"
#     healthy_threshold   = 5
#     unhealthy_threshold = 2
#     timeout             = 5
#   }
# }

# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = 80
#   protocol          = "HTTP"
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }

provider "aws" {
  region = var.region
}

# call the vpc module

module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
}

# call subnets module

module "subnets" {
  source                = "./modules/sn"
  vpc_id                = module.vpc.vpc_id
  public_subnets_cidrs  = var.public_subnets_cidrs
  private_subnets_cidrs = var.private_subnets_cidrs
  availability_zones    = var.availability_zones
  igw_id                = module.vpc.igw_id
}
