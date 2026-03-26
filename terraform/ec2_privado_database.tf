resource "aws_instance" "instancia_database_privada" {
  ami           = aws_ami_from_instance.ami_toomate.id
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

  # Volume adicional para dados do banco
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = false
  }

  user_data = <<-EOF
#!/bin/bash
# Montar volume adicional para dados do banco
mkdir -p /var/lib/mysql
mkfs.ext4 /dev/nvme1n1
mount /dev/nvme1n1 /var/lib/mysql

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
  lucaspaessptech/toomate:database
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
