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

resource "aws_subnet" "subnet_toomate_publico_2" {
  vpc_id                  = aws_vpc.vpc_toomate.id
  cidr_block              = "10.0.1.128/25"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_toomate_publico_2"
  }
}

resource "aws_subnet" "subnet_toomate_privado" {
  vpc_id                  = aws_vpc.vpc_toomate.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

    tags = {
    Name = "subnet_toomate_privado"
  }
}

resource "aws_subnet" "subnet_toomate_privado_2" {
  vpc_id                  = aws_vpc.vpc_toomate.id
  cidr_block              = "10.0.0.128/25"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet_toomate_privado_2"
  }
}

resource "aws_internet_gateway" "igw_toomate" {
  vpc_id = aws_vpc.vpc_toomate.id

  tags = {
    Name = "igw_toomate"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet_toomate_publico.id

  depends_on = [aws_internet_gateway.igw_toomate]

  tags = {
    Name = "nat-toomate"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc_toomate.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.rt_toomate_privado.id]

  tags = {
    Name = "toomate-s3-endpoint"
  }
}