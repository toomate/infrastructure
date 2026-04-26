resource "aws_instance" "rabbit" {
  ami                         = aws_ami_from_instance.ami_toomate.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_toomate_privado.id
  key_name                    = "vockey"
  vpc_security_group_ids      = [aws_security_group.rabbit_sg.id]
  tags = { Name = "rabbitmq-single" }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

   user_data = <<-EOF
#!/bin/bash
set -e

systemctl enable --now docker

mkdir -p /opt/microservices
cat >/opt/microservices/docker-compose.yml <<'YAML'
version: '3.8'
services:
  rabbitmq:
    image: 'rabbitmq:4.2.4-management'
    environment:
      - 'RABBITMQ_DEFAULT_PASS=secret'
      - 'RABBITMQ_DEFAULT_USER=myuser'
    ports:
      - "5672:5672"
      - "15672:15672"

  microservico-notif:
    image: lucaspaessptech/toomate:microservice
    environment:
      - SPRING_RABBITMQ_HOST=rabbitmq
      - SPRING_RABBITMQ_PORT=5672
      - SPRING_RABBITMQ_USERNAME=myuser
      - SPRING_RABBITMQ_PASSWORD=secret
    ports:
      - "8182:8182"
    depends_on:
      - rabbitmq
YAML

# Run docker compose (retry until docker is ready)
for i in {1..10}; do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

cd /opt/microservices
docker compose up -d

EOF
}