# public subnet
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets_cidrs)
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnets_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  #   assign_ipv6_address_on_creation = true
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }

}

# route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  tags = {
    Name = "Public Route Table"
  }
}


# associate public subnets with the public route table

resource "aws_route_table_association" "public_association" {
  count          = length(var.public_subnets_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#private subnet
resource "aws_subnet" "private" {
  vpc_id     = var.vpc_id
  count      = length(var.private_subnets_cidrs)
  cidr_block = var.private_subnets_cidrs[count.index]
  #   assign_ipv6_address_on_creation = true
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# create private route table

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id
  tags = {
    Name = "Private Route Table"
  }
}

# Create route for private subnets via  NAT

resource "aws_route" "private_route" {
  count                  = length(var.private_subnets_cidrs)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

# Associate private subnets with the private route table
resource "aws_route_table_association" "private_association" {
  count          = length(var.private_subnets_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


# create nat

resource "aws_eip" "nat_eip" {
  count = length(var.public_subnets_cidrs)
  tags = {
    Name = "EIP NAT Private VPC ${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.public_subnets_cidrs)
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "Nat Private VPC-${count.index + 1}"
  }
}

resource "aws_route" "public_internet_gw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.igw_id
}

resource "aws_route" "private_internet_gw" {
  count                  = length(var.private_subnets_cidrs)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat[count.index].id
  lifecycle {
    ignore_changes = [destination_cidr_block]
  }
}
