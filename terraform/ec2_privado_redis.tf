resource "aws_instance" "instancia_toomate_privada" {
  ami                         = "ami-0b6c6ebed2801a5cb"
  instance_type               = "t2.medium"
  key_name                    = "vockey"
  user_data_replace_on_change = true
  iam_instance_profile        = "LabInstanceProfile"

  subnet_id = element[
    aws_subnet.subnet_toomate_privado.id
  ]

  vpc_security_group_ids = [aws_security_group.sg_privado_redis_tag.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size           = 16
    volume_type           = "gp3"
    delete_on_termination = true
  }

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

# Pull das imagens Docker
docker pull redis:7-alpine

until timeout 2 bash -c "cat < /dev/null > /dev/tcp/${aws_instance.instancia_database_privada.private_ip}/3306"; do
  sleep 5
done

docker rm -f redis || true
docker run -d --name redis -p 6379:6379 \
  --restart unless-stopped \
  redis:7-alpine

EOF

  tags = {
    Name = "Instancia privada redis Toomate"
  }
}
