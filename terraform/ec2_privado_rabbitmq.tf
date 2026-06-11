resource "aws_instance" "rabbit" {
  ami                    = "ami-0b6c6ebed2801a5cb"
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.subnet_toomate_privado.id
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.rabbit_sg.id]

  # IP privado fixo: ao recriar o rabbit (ex: mudanca no user_data) o IP nao muda,
  # entao backend, site e observability (que referenciam este IP) nao recriam junto.
  private_ip = "10.0.0.76"

  # Faz a mudanca de user_data (ex: habilitar plugin de metricas) recriar a EC2,
  # caso contrario o novo user_data nunca roda na instancia existente.
  user_data_replace_on_change = true

  tags = { Name = "rabbitmq-single" }

  root_block_device {
    volume_size           = 20
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

systemctl enable --now docker

mkdir -p /opt/microservices

# Habilita o plugin de metricas do RabbitMQ (expoe Prometheus em :15692).
# Sem isso nada escuta no 15692 e o job 'rabbitmq' do Prometheus fica down.
cat >/opt/microservices/enabled_plugins <<'PLUGINS'
[rabbitmq_management,rabbitmq_prometheus].
PLUGINS

cat >/opt/microservices/docker-compose.yml <<'YAML'
version: '3.8'
services:
  rabbitmq:
    image: 'rabbitmq:4.2.4-management'
    environment:
      - 'RABBITMQ_DEFAULT_PASS=secret'
      - 'RABBITMQ_DEFAULT_USER=myuser'
    volumes:
      - ./enabled_plugins:/etc/rabbitmq/enabled_plugins:ro
    ports:
      - "5672:5672"
      - "15672:15672"
      - "15692:15692"

  microservico-notif:
    image: lucaspaessptech/toomate:microservice
    environment:
      - SPRING_RABBITMQ_HOST=rabbitmq
      - SPRING_RABBITMQ_PORT=5672
      - SPRING_RABBITMQ_USERNAME=myuser
      - SPRING_RABBITMQ_PASSWORD=secret
    ports:
      - "8181:8181"
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