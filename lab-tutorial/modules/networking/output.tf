output "vpc_id" {
  value = aws_vpc.vpc.id
}
output "private_subnet_1a" {
  value = aws_subnet.private_subnet[0].id
}
output "private_subnet_1b" {
  value = aws_subnet.private_subnet[1].id
}
