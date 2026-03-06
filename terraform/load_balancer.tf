resource "aws_lb" "alb_toomate" {
  name               = "alb-toomate"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]

  subnets = [
    aws_subnet.subnet_toomate_publico.id,
    aws_subnet.subnet_toomate_publico_2.id
  ]
}

resource "aws_lb_target_group" "tg_toomate" {
  name        = "tg-toomate"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc_toomate.id
  target_type = "ip"

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-499"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg_toomate.arn
  target_id = aws_instance.instancia_toomate_privada[count.index].private_ip
  port             = 8080
}

resource "aws_lb_listener" "listener_http" {
    depends_on = [
    aws_lb_target_group.tg_toomate
  ]
  load_balancer_arn = aws_lb.alb_toomate.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_toomate.arn
  }
}