resource "aws_instance" "instancia_toomate_analise" {
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
