###############################################################################
# Observability stack (Prometheus + Grafana + mysqld-exporter)
#
# EC2 publica na subnet publica com IP publico. Acessa Grafana em:
#   http://<public_ip>:3001  (admin/admin)
# E Prometheus em:
#   http://<public_ip>:9090
#
# Dependencias: VPC, subnets publicas, EC2s do backend/rabbitmq/database.
# Para subir somente esta stack:
#   terraform apply --% -target=aws_instance.observability ...
###############################################################################

resource "aws_security_group" "sg_observability" {
  name        = "sg_observability"
  description = "SG da EC2 de observability (Prometheus + Grafana)"
  vpc_id      = aws_vpc.vpc_toomate.id

  ingress {
    description      = "SSH"
    from_port        = var.porta_ssh
    to_port          = var.porta_ssh
    protocol         = "tcp"
    cidr_blocks      = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
  }

  ingress {
    description      = "Grafana UI"
    from_port        = 3001
    to_port          = 3001
    protocol         = "tcp"
    cidr_blocks      = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
  }

  ingress {
    description      = "Prometheus UI"
    from_port        = 9090
    to_port          = 9090
    protocol         = "tcp"
    cidr_blocks      = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
  }

  tags = {
    Name = "sg_observability"
  }
}

# Regras aditivas nos SGs existentes para permitir scrape vindo desta EC2.
# Usam aws_vpc_security_group_ingress_rule porque os SGs originais ja tem
# regras inline (nao da pra misturar com aws_security_group_rule).

resource "aws_vpc_security_group_ingress_rule" "backend_scrape" {
  security_group_id            = aws_security_group.sg_privado_tag.id
  referenced_security_group_id = aws_security_group.sg_observability.id
  from_port                    = var.spring_porta
  to_port                      = var.spring_porta
  ip_protocol                  = "tcp"
  description                  = "Prometheus scrape do backend"
}

resource "aws_vpc_security_group_ingress_rule" "mysql_scrape" {
  security_group_id            = aws_security_group.sg_privado_database.id
  referenced_security_group_id = aws_security_group.sg_observability.id
  from_port                    = var.database_porta
  to_port                      = var.database_porta
  ip_protocol                  = "tcp"
  description                  = "mysqld-exporter scrape do MySQL"
}

resource "aws_vpc_security_group_ingress_rule" "rabbitmq_metrics_scrape" {
  security_group_id            = aws_security_group.rabbit_sg.id
  referenced_security_group_id = aws_security_group.sg_observability.id
  from_port                    = 15692
  to_port                      = 15692
  ip_protocol                  = "tcp"
  description                  = "Prometheus scrape do plugin rabbitmq_prometheus"
}

resource "aws_vpc_security_group_ingress_rule" "microservice_scrape" {
  security_group_id            = aws_security_group.rabbit_sg.id
  referenced_security_group_id = aws_security_group.sg_observability.id
  from_port                    = 8182
  to_port                      = 8182
  ip_protocol                  = "tcp"
  description                  = "Prometheus scrape do microservico-notif"
}

resource "aws_instance" "observability" {
  ami                  = "ami-0b6c6ebed2801a5cb"
  instance_type        = "t3.small"
  key_name             = "vockey"
  subnet_id            = aws_subnet.subnet_toomate_publico.id
  iam_instance_profile = "LabInstanceProfile"

  vpc_security_group_ids      = [aws_security_group.sg_observability.id]
  associate_public_ip_address = true
  user_data_replace_on_change = true

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

  tags = {
    Name = "toomate-observability"
  }

  user_data = <<-EOF
#!/bin/bash
set -e

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

mkdir -p /opt/observability/prometheus
mkdir -p /opt/observability/grafana/provisioning/datasources
mkdir -p /opt/observability/grafana/provisioning/dashboards/infra
mkdir -p /opt/observability/grafana/provisioning/dashboards/cliente

# ---- prometheus.yml ----
cat >/opt/observability/prometheus/prometheus.yml <<YAML
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: backend
    metrics_path: /actuator/prometheus
    static_configs:
      - targets:
          - "${aws_instance.instancia_toomate_privada[0].private_ip}:8080"
          - "${aws_instance.instancia_toomate_privada[1].private_ip}:8080"

  - job_name: microservico-notif
    metrics_path: /actuator/prometheus
    static_configs:
      - targets: ["${aws_instance.rabbit.private_ip}:8182"]

  - job_name: mysql
    static_configs:
      - targets: ["mysqld-exporter:9104"]

  - job_name: rabbitmq
    static_configs:
      - targets: ["${aws_instance.rabbit.private_ip}:15692"]
YAML

# ---- Grafana datasources ----
cat >/opt/observability/grafana/provisioning/datasources/datasources.yml <<YAML
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Athena
    type: grafana-athena-datasource
    uid: athena
    jsonData:
      authType: default
      defaultRegion: us-east-1
      catalog: AwsDataCatalog
      database: toomate
      workgroup: toomate
      outputLocation: s3://${aws_s3_bucket.athena_results.bucket}/output/

  # Conexao direta no MySQL para dashboards que rodam SQL na base transacional.
  # Prod: aponta para o IP privado da EC2 do banco (porta liberada pela regra mysql_scrape).
  - name: MySQL Toomate
    type: mysql
    uid: mysql-toomate
    url: ${aws_instance.instancia_database_privada.private_ip}:${var.database_porta}
    user: ${var.db_user}
    jsonData:
      database: ${var.db_name}
    secureJsonData:
      password: ${var.db_password}
YAML

# ---- Dashboards provider ----
cat >/opt/observability/grafana/provisioning/dashboards/dashboards.yml <<YAML
apiVersion: 1
providers:
  - name: toomate-infra
    folder: Infra
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards/infra
  - name: toomate-cliente
    folder: Visao Cliente
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards/cliente
YAML

# ---- Baixar dashboards comunidade (mesmos que rodam local) ----
apt-get install -y python3

download_dash() {
  local id=$1 rev=$2 file=$3
  curl -sSL "https://grafana.com/api/dashboards/$id/revisions/$rev/download" -o "/tmp/$file"
  python3 - "$file" <<'PYEOF'
import json, sys
fname = sys.argv[1]
d = json.load(open('/tmp/' + fname))
for k in ('__inputs', '__requires', '__elements'):
    d.pop(k, None)
d['id'] = None
d['uid'] = None
txt = json.dumps(d).replace('$${DS_PROMETHEUS}', 'Prometheus')
open('/opt/observability/grafana/provisioning/dashboards/infra/' + fname, 'w').write(txt)
PYEOF
}

download_dash 4701  10 spring-boot-jvm.json
download_dash 14057 1  mysql.json
download_dash 10991 15 rabbitmq.json

# ---- Dashboards custom da Visao Cliente ----
%{ for f in fileset("${path.module}/../grafana/provisioning/dashboards/cliente", "*.json") ~}
echo '${base64encode(file("${path.module}/../grafana/provisioning/dashboards/cliente/${f}"))}' | base64 -d > /opt/observability/grafana/provisioning/dashboards/cliente/${f}
%{ endfor ~}

# ---- docker-compose.yml ----
cat >/opt/observability/docker-compose.yml <<YAML
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: toomate_prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    restart: always

  grafana:
    image: grafana/grafana-oss:latest
    container_name: toomate_grafana
    ports:
      - "3001:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
      GF_INSTALL_PLUGINS: grafana-athena-datasource
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: Viewer
      AWS_SDK_LOAD_CONFIG: "true"
      AWS_DEFAULT_REGION: us-east-1
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    depends_on:
      - prometheus
    restart: always

  mysqld-exporter:
    image: prom/mysqld-exporter:latest
    container_name: toomate_mysqld_exporter
    command:
      - "--mysqld.username=toomate_user:toomate_password"
      - "--mysqld.address=${aws_instance.instancia_database_privada.private_ip}:3306"
      - "--no-collect.slave_status"
    ports:
      - "9104:9104"
    restart: always

volumes:
  prometheus_data:
  grafana_data:
YAML

# Espera Docker e sobe
for i in {1..15}; do
  if docker info >/dev/null 2>&1; then break; fi
  sleep 2
done

cd /opt/observability
docker compose up -d
EOF
}

# Elastic IP fixo: mantem o mesmo endereco mesmo quando a EC2 e recriada
# (ex: mudanca no user_data com user_data_replace_on_change = true).
resource "aws_eip" "observability" {
  domain   = "vpc"
  instance = aws_instance.observability.id

  tags = {
    Name = "toomate-observability-eip"
  }
}

output "observability_public_ip" {
  description = "IP publico (Elastic IP) da EC2 de observability"
  value       = aws_eip.observability.public_ip
}

output "grafana_url" {
  description = "URL do Grafana"
  value       = "http://${aws_eip.observability.public_ip}:3001"
}

output "prometheus_url" {
  description = "URL do Prometheus"
  value       = "http://${aws_eip.observability.public_ip}:9090"
}
