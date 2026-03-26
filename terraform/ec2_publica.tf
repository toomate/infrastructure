resource "aws_instance" "instancia_toomate_publica" {
  ami           = aws_ami_from_instance.ami_toomate.id
  instance_type = "t2.medium"
  key_name      = "vockey"

  subnet_id = aws_subnet.subnet_toomate_publico.id
  vpc_security_group_ids = [aws_security_group.sg_publico_tag.id]

  tags = {
    Name = "Instancia pública Toomate"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 16
    volume_type = "gp3"
  }

  user_data = <<-EOF
#!/bin/bash
docker run -e API_URL=http://${aws_lb.alb_toomate.dns_name} --name frontend -p 80:80 -d lucaspaessptech/toomate:frontend
EOF
}

output "site_public_ip" {
  description = "IP público da instância pública"
  value       = aws_instance.instancia_toomate_publica.public_ip
}

