provider "aws" {
  alias  = "provider_hk"
  region = "ap-east-1"
}

provider "aws" {
  alias  = "provider_mb"
  region = "ap-south-1"
}

# VPC1 (in HK)

resource "aws_vpc" "hk" {
  provider   = aws.provider_hk
  cidr_block = "10.10.0.0/16"
}

resource "aws_vpc" "mb" {
  provider   = aws.provider_mb
  cidr_block = "10.50.0.0/16"
}

#VPC peering
resource "aws_vpc_peering_connection" "peering" {
  provider    = aws.provider_mb
  peer_vpc_id = aws_vpc.hk.id
  vpc_id      = aws_vpc.mb.id
  peer_region = "ap-south-1"

  tags = {
    Name = "vpc-peering-between-mb-and-hk"
  }
}

resource "aws_route" "route_mb_hk" {
  provider                  = aws.provider_mb
  route_table_id            = aws_vpc.mb.main_route_table_id
  destination_cidr_block    = aws_vpc.hk.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}

resource "aws_route" "route_hk_mb" {
  provider                  = aws.provider_hk
  route_table_id            = aws_vpc.hk.main_route_table_id
  destination_cidr_block    = aws_vpc.mb.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}
