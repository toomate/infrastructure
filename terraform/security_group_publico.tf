resource "aws_security_group" "sg_publico_tag" {
  name        = "sg_publico"
  description = "Security group publico"
  vpc_id      = aws_vpc.vpc_toomate.id

  ingress {
    description      = "Permitir entrade ssh de todos os ips"
    from_port        = var.porta_ssh
    to_port          = var.porta_ssh
    protocol         = "tcp"
    cidr_blocks      = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
  }

  ingress {
    description      = "Permitir entrada react de todos os ips"
    from_port        = var.react_porta
    to_port          = var.react_porta
    protocol         = "tcp"
    cidr_blocks      = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
  }

    ingress {
    description      = "Permitir entrada waha de todos os ips"
    from_port        = var.waha_porta
    to_port          = var.waha_porta
    protocol         = "tcp"
    cidr_blocks      = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
  }

  tags = {
    Name = "Security group público"
  }

}
