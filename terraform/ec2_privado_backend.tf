resource "aws_instance" "instancia_toomate_privada" {
  count         = 2
  ami           = aws_ami_from_instance.ami_toomate.id
  instance_type = "t2.medium"
  key_name      = "vockey"
  user_data_replace_on_change = true

  subnet_id = element([
    aws_subnet.subnet_toomate_privado.id,
    aws_subnet.subnet_toomate_privado_2.id
  ], count.index)

  vpc_security_group_ids = [aws_security_group.sg_privado_tag.id]

  root_block_device {
    volume_size           = 16
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
set -e

systemctl enable docker
systemctl start docker

until timeout 2 bash -c "cat < /dev/null > /dev/tcp/${aws_instance.instancia_database_privada.private_ip}/3306"; do
  sleep 5
done

docker rm -f backend || true
docker run -d --name backend -p 8080:8080 \
  --restart unless-stopped \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://${aws_instance.instancia_database_privada.private_ip}:3306/toomate \
  -e SPRING_DATASOURCE_USERNAME=toomate_user \
  -e SPRING_DATASOURCE_PASSWORD=toomate_password \
  lucaspaessptech/toomate:backend

# Cadastra usuario padrao apenas na instancia 0.
if [ "${count.index}" -eq 0 ]; then
  until curl -fsS http://localhost:8080/v3/api-docs > /dev/null; do
    sleep 5
  done

  HTTP_CODE=$(curl -s -o /tmp/bootstrap_usuario_response.txt -w "%%{http_code}" \
    -X POST http://localhost:8080/usuarios \
    -H "Content-Type: application/json" \
    -d '{"nome":"Toomate Dev","apelido":"toomatedev","senha":"toomatesenha","administrador":true}')

  if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
    cat /tmp/bootstrap_usuario_response.txt >> /var/log/bootstrap_usuario.log
  fi
fi
EOF

  tags = {
    Name = "Instancia privada Toomate ${count.index}"
  }
}
