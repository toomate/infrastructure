resource "aws_security_group" "sg_privado_tag" {
  name        = "sg_privado"
  description = "Security group privado"
  vpc_id      = aws_vpc.vpc_toomate.id


  ingress {
    description     = "Permitir entrade ssh de todos os ips"
    from_port       = var.porta_ssh
    to_port         = var.porta_ssh
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_publico_tag.id]
  }

  ingress {
    description     = "Permitir entrada https e https de todos os ips"
    from_port       = var.spring_porta
    to_port         = var.spring_porta
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_publico_tag.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security group privado"
  }

}
