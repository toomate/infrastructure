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
  security_groups = [aws_security_group.sg_alb.id, aws_security_group.sg_publico_tag.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.sg_publico_tag.id]
  }

  # Prometheus (EC2 observability) coleta o plugin rabbitmq_prometheus.
  ingress {
    description     = "Prometheus scrape do plugin rabbitmq_prometheus (observability)"
    from_port       = 15692
    to_port         = 15692
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_observability.id]
  }

  # Prometheus coleta o microservico-notif (mesma porta da app: microservice_porta).
  ingress {
    description     = "Prometheus scrape do microservico-notif (observability)"
    from_port       = var.microservice_porta
    to_port         = var.microservice_porta
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_observability.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}