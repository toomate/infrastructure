resource "aws_instance" "instancia_toomate_privada" {
  count                       = 2
  ami                         = "ami-0b6c6ebed2801a5cb"
  instance_type               = "t2.medium"
  key_name                    = "vockey"
  user_data_replace_on_change = true
  iam_instance_profile        = "LabInstanceProfile"

  subnet_id = element([
    aws_subnet.subnet_toomate_privado.id,
    aws_subnet.subnet_toomate_privado_2.id
  ], count.index)

  vpc_security_group_ids = [aws_security_group.sg_privado_tag.id]

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
docker pull lucaspaessptech/toomate:backend
docker pull lucaspaessptech/toomate:frontend
docker pull rabbitmq:4.2.4-management

until timeout 2 bash -c "cat < /dev/null > /dev/tcp/${aws_instance.instancia_database_privada.private_ip}/3306"; do
  sleep 5
done

docker rm -f backend || true
docker run -d --name backend -p 8080:8080 \
  --restart unless-stopped \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://${aws_instance.instancia_database_privada.private_ip}:3306/toomate \
  -e SPRING_DATASOURCE_USERNAME=toomate_user \
  -e SPRING_DATASOURCE_PASSWORD=toomate_password \
  -e SPRING_RABBITMQ_ADDRESSES=amqp://myuser:secret@${aws_instance.rabbit.private_ip}:5672/ \
  -e SPRING_DATA_REDIS_HOST=${aws_instance.instancia_toomate_privada_redis.private_ip} \
  lucaspaessptech/toomate:backend
EOF

  tags = {
    Name = "Instancia privada Toomate ${count.index}"
  }
}
