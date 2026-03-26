resource "aws_instance" "instancia_toomate_privada" {
  count         = 2
  ami           = aws_ami_from_instance.ami_toomate.id
  instance_type = "t2.medium"
  key_name      = "vockey"

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
cd /home/ubuntu
docker run -d --name backend -p 8080:8080 \
  -e DATABASE_HOST=${aws_instance.instancia_database_privada.private_ip} \
  -e DATABASE_PORT=3306 \
  -e DATABASE_USER=toomate_user \
  -e DATABASE_PASSWORD=toomate_password \
  lucaspaessptech/toomate:backend

# Aguarda o backend estar 100% inicializado e cadastra usuario padrao apenas na instancia 0.
if [ "${count.index}" -eq 0 ]; then
  until curl -s http://localhost:8080/actuator/health | grep -q '"status":"UP"'; do
    sleep 5
  done

  HTTP_CODE=$(curl -s -o /tmp/bootstrap_usuario_response.txt -w "%{http_code}" \
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
