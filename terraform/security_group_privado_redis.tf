resource "aws_security_group" "sg_privado_redis_tag" {
  name        = "sg_privado_redis"
  description = "Security group privado redis"
  vpc_id      = aws_vpc.vpc_toomate.id


  ingress {
    description     = "Permitir entrade ssh de todos os ips"
    from_port       = var.porta_ssh
    to_port         = var.porta_ssh
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_publico_tag.id]
  }

  ingress {
description = "Permitir acesso da aplicação na porta 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_alb.id]
  }

  ingress {
  description     = "Redis"
  from_port       = 6379
  to_port         = 6379
  protocol        = "tcp"
  security_groups = [aws_security_group.sg_privado_tag]
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security group privado redis"
  }

}
