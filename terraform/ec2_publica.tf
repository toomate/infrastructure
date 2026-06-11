resource "aws_instance" "instancia_toomate_publica" {
  ami           = "ami-0b6c6ebed2801a5cb"
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

  depends_on = [
  aws_instance.rabbit
]

  user_data = <<-EOF
#!/bin/bash
set -e

# Instalar Docker
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

# Configuração da aplicação
apt install uuid-runtime -y
mkdir -p /etc/toomate
KEY=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || (command -v uuidgen >/dev/null 2>&1 && uuidgen) || python3 -c 'import uuid;print(uuid.uuid4())')
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)

PUBLIC_IP=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

cat >/etc/toomate/containers.env <<EOT
API_URL=http://${aws_lb.alb_toomate.dns_name}
GRAFANA_URL=http://${aws_eip.observability.public_ip}:3001
VITE_SSE_URL=/sse/
SSE_UPSTREAM=http://${aws_instance.rabbit.private_ip}:8181
VITE_WAHA_API_KEY=$KEY
VITE_WAHA_API_URL=http://$PUBLIC_IP:3000
WAHA_DASHBOARD_USERNAME=admin
WAHA_DASHBOARD_PASSWORD=$KEY
WHATSAPP_SWAGGER_USERNAME=admin
WHATSAPP_SWAGGER_PASSWORD=$KEY
WHATSAPP_DEFAULT_ENGINE=WEBJS
WAHA_NAMESPACE=all
WAHA_BASE_URL=http://$PUBLIC_IP:3000
WAHA_LOG_FORMAT=JSON
WAHA_LOG_LEVEL=info
WAHA_PRINT_QR=False
WAHA_API_KEY=$KEY
EOT

docker network create toomate_network || true
docker run -v `pwd`/.sessions:/app/.sessions --network toomate_network --env-file /etc/toomate/containers.env --name waha -p 3000:3000 -d devlikeapro/waha
docker run --network toomate_network --env-file /etc/toomate/containers.env --name frontend -p 80:80 -d lucaspaessptech/toomate:frontend
EOF
}

output "site_public_ip" {
  description = "IP público da instância pública"
  value       = aws_instance.instancia_toomate_publica.public_ip
}

