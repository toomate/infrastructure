resource "aws_instance" "instancia_database_privada" {
  ami           = "ami-0b6c6ebed2801a5cb"
  instance_type = "t2.medium"
  key_name      = "vockey"

  subnet_id = aws_subnet.subnet_toomate_privado.id

  vpc_security_group_ids = [aws_security_group.sg_privado_database.id]

  # Volume raiz
  root_block_device {
    volume_size           = 16
    volume_type           = "gp3"
    delete_on_termination = true
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

# Pull da imagem Docker do banco
docker pull lucaspaessptech/toomate:database

# Executar container MySQL
cd /home/ubuntu
docker run -d \
  --name database \
  -p 3306:3306 \
  -v /var/lib/mysql:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=toomate_root_password \
  -e MYSQL_DATABASE=toomate \
  -e MYSQL_USER=toomate_user \
  -e MYSQL_PASSWORD=toomate_password \
  lucaspaessptech/toomate:database \
  --lower_case_table_names=1

EOF

  tags = {
    Name = "Instancia privada Database Toomate"
  }
}

# Output do IP privado do banco de dados
output "database_private_ip" {
  description = "IP privado da instância de banco de dados"
  value       = aws_instance.instancia_database_privada.private_ip
}
