resource "aws_instance" "builder_toomate" {
  ami                         = "ami-0b6c6ebed2801a5cb"
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.subnet_toomate_publico.id
  vpc_security_group_ids      = [aws_security_group.sg_publico_tag.id]
  associate_public_ip_address = true
  key_name                    = "vockey"

  user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker pull lucaspaessptech/toomate:database
docker pull lucaspaessptech/toomate:backend
docker pull lucaspaessptech/toomate:frontend

cat <<EOT > /home/ubuntu/compose.yaml
version: '3.8'

services:

  mysql:
    image: lucaspaessptech/toomate:database
    command: --lower_case_table_names=1
    container_name: toomate_mysql
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: toomate
    restart: always
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 5s
      retries: 10

  backend:
    image: lucaspaessptech/toomate:backend
    container_name: toomate_backend
    depends_on:
      mysql:
        condition: service_healthy
    ports:
      - "8080:8080"
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/toomate
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: root
    restart: always

volumes:
  mysql_data:
EOT

touch /home/ubuntu/BUILD_COMPLETE
EOF

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("labsuser.pem")
  }

  tags = {
    Name = "builder-toomate"
  }
}

resource "terraform_data" "wait_for_build" {

  depends_on = [aws_instance.builder_toomate]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.builder_toomate.public_ip
      user        = "ubuntu"
      private_key = file("labsuser.pem")
    }

    inline = [
      "while [ ! -f /home/ubuntu/BUILD_COMPLETE ]; do sleep 5; done"
    ]
  }
}

resource "terraform_data" "destroy_builder" {

  depends_on = [aws_ami_from_instance.ami_toomate]

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.builder_toomate.id}"
  }
}
