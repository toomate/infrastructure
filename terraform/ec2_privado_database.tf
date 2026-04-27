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

  user_data = <<-EOF
#!/bin/bash

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
