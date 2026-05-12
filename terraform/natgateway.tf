# NAT Gateway na subnet pública
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "nat-eip"
  }

  depends_on = [aws_internet_gateway.igw_toomate]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet_toomate_publico.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw_toomate]
}

# Adicionar rota na Route Table privada
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.rota_privada.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route" "private_nat_route_2" {
  route_table_id         = aws_route_table.rota_privada_2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}