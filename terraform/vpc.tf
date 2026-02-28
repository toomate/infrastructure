resource "aws_vpc" "vpc_toomate" {
  cidr_block           = "10.0.0.0/23"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc_toomate"
  }
}

resource "aws_subnet" "subnet_toomate_publico" {
  vpc_id                  = aws_vpc.vpc_toomate.id
  cidr_block              = "10.0.1.0/25"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_toomate_publico"
  }
}

resource "aws_subnet" "subnet_toomate_privado" {
  vpc_id                  = aws_vpc.vpc_toomate.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
}

resource "aws_internet_gateway" "igw_toomate" {
  vpc_id = aws_vpc.vpc_toomate.id

  tags = {
    Name = "igw_toomate"
  }

}

resource "aws_route_table" "rt_toomate_publico" {
  vpc_id = aws_vpc.vpc_toomate.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_toomate.id
  }

  tags = {
    Name = "rt_toomate_publico"
  }
}
