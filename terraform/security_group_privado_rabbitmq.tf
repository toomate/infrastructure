resource "aws_security_group" "rabbit_sg" {
  name        = "rabbit-sg"
  vpc_id      = aws_vpc.vpc_toomate.id
  description = "RabbitMQ SG - only app and admin access"

  ingress {
    description      = "Porta do RabbitMQ"
    from_port        = 5672
    to_port          = 5672
    protocol         = "tcp"
    security_groups  = [aws_security_group.sg_privado_tag.id]
  }

  ingress {
    description     = "Porta da interface de gerenciamento"
    from_port       = 15672
    to_port         = 15672
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_publico_tag.id]
  }

  ingress {
  description     = "Porta do microservico de notificacoes"
  from_port       = var.microservice_porta
  to_port         = var.microservice_porta
  protocol        = "tcp"
  security_groups = [aws_security_group.sg_alb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.sg_publico_tag.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}