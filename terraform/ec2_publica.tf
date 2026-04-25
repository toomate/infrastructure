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
set -e
mkdir -p /etc/toomate
KEY=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || (command -v uuidgen >/dev/null 2>&1 && uuidgen) || python3 -c 'import uuid;print(uuid.uuid4())')

cat >/etc/toomate/containers.env <<EOT
API_URL=http://${aws_lb.alb_toomate.dns_name}
VITE_WAHA_API_KEY=$KEY
VITE_WAHA_API_URL=http://waha:3000
WAHA_DASHBOARD_USERNAME=admin
WAHA_DASHBOARD_PASSWORD=$KEY
WHATSAPP_SWAGGER_USERNAME=admin
WHATSAPP_SWAGGER_PASSWORD=$KEY
WHATSAPP_DEFAULT_ENGINE=WEBJS
WAHA_NAMESPACE=all
WAHA_BASE_URL=http://waha:3000
WAHA_LOG_FORMAT=JSON
WAHA_LOG_LEVEL=info
WAHA_PRINT_QR=False
WAHA_API_KEY=$KEY

EOT
docker network create toomate_network || true
docker run --network toomate_network --env-file /etc/toomate/containers.env --name waha -p 3000:3000 -d devlikeapro/waha
docker run --network toomate_network --env-file /etc/toomate/containers.env --name frontend -p 80:80 -d lucaspaessptech/toomate:frontend
EOF
}

output "site_public_ip" {
  description = "IP público da instância pública"
  value       = aws_instance.instancia_toomate_publica.public_ip
}

