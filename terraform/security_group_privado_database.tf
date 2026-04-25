resource "aws_security_group" "sg_privado_database" {
  name        = "sg_privado_database"
  description = "Security group privado debanco de dados"
  vpc_id      = aws_vpc.vpc_toomate.id

  # SSH apenas da subnet privada
  ingress {
    description = "SSH da subnet privada"
    from_port   = var.porta_ssh
    to_port     = var.porta_ssh
    protocol    = "tcp"
    cidr_blocks = [
      aws_subnet.subnet_toomate_privado.cidr_block,
      aws_subnet.subnet_toomate_privado_2.cidr_block
    ]
  }

  # MySQL apenas da subnet privada
  ingress {
    description = "MySQL da subnet privada"
    from_port   = var.database_porta
    to_port     = var.database_porta
    protocol    = "tcp"
    cidr_blocks = [
      aws_subnet.subnet_toomate_privado.cidr_block,
      aws_subnet.subnet_toomate_privado_2.cidr_block
    ]
  }

  # Egress - permitir todo tráfego saindo
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security group privado database"
  }
}
