resource "aws_instance" "instancia_toomate_analise" {
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

  user_data = <<-EOF
#!/bin/bash

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

cat <<EOT > /home/ubuntu/Dockerfile
FROM jupyter/scipy-notebook

USER root
RUN fix-permissions /home/jovyan
USER jovyan
EOT 

cat <<EOT > /home/ubuntu/compose.yaml
services:
  mysql:
    image: mysql:8.0
    container_name: mysql-analise-dados
    environment:
      MYSQL_ROOT_PASSWORD: admin
      MYSQL_DATABASE: admin
      MYSQL_USER: admin
      MYSQL_PASSWORD: admin
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./sql:/docker-entrypoint-initdb.d
    restart: unless-stopped

  jupyter:
    build: .
    container_name: jupyter-analise-dados
    ports:
      - "8888:8888"
    volumes:
      - ./notebooks:/home/jovyan/work
      - ./sql:/home/jovyan/sql
    environment:
      JUPYTER_TOKEN: "pass"
    depends_on:
      - mysql
    restart: unless-stopped

volumes:
  mysql_data:
EOT 

docker compose -f /home/ubuntu/compose.yaml up -d
EOF
}
