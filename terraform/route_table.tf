
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

resource "aws_route_table_association" "publico_assoc_1" {
  subnet_id      = aws_subnet.subnet_toomate_publico.id
  route_table_id = aws_route_table.rt_toomate_publico.id
}

resource "aws_route_table_association" "publico_assoc_2" {
  subnet_id      = aws_subnet.subnet_toomate_publico_2.id
  route_table_id = aws_route_table.rt_toomate_publico.id
}
