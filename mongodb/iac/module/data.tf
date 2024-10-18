data "aws_region" "this" {

}

data "aws_subnet" "selected" {
  id = var.private_subnets[0]
}
