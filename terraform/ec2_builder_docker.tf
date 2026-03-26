resource "aws_instance" "builder_toomate" {
  ami                         = "ami-0b6c6ebed2801a5cb"
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.subnet_toomate_publico.id
  vpc_security_group_ids      = [aws_security_group.sg_publico_tag.id]
  associate_public_ip_address = true
  key_name                    = "vockey"
  user_data_replace_on_change = true

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail
exec > >(tee -a /var/log/user-data-builder.log) 2>&1

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

for i in $(seq 1 30); do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

for image in lucaspaessptech/toomate:database lucaspaessptech/toomate:backend lucaspaessptech/toomate:frontend; do
  for i in $(seq 1 12); do
    if docker pull "$image"; then
      break
    fi
    if [ "$i" -eq 12 ]; then
      echo "Falha no pull da imagem $image"
      exit 1
    fi
    sleep 10
  done
done

docker image ls

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
