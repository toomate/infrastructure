resource "aws_instance" "rabbit" {
  ami                         = aws_ami_from_instance.ami_toomate.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_toomate_privado.id
  key_name                    = "vockey"
  vpc_security_group_ids      = [aws_security_group.rabbit_sg.id]
  tags = { Name = "rabbitmq-single" }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

   user_data = <<-EOF
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Atualiza e instala ferramentas
apt-get update
apt-get install -y curl gnupg apt-transport-https cloud-guest-utils ca-certificates

# Formata e monta EBS (device /dev/xvdf -> /var/lib/rabbitmq)
DISK="/dev/xvdf"
MOUNT="/var/lib/rabbitmq"
if [ -b "$DISK" ]; then
  if ! blkid $DISK >/dev/null 2>&1; then
    mkfs.ext4 -F $DISK
  fi
  mkdir -p $MOUNT
  if ! grep -qs "$DISK" /etc/fstab; then
    echo "$DISK $MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  mount -a || true
fi

# Erlang repo/package
curl -fsSL https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb -o /tmp/erlang-sol.deb
dpkg -i /tmp/erlang-sol.deb || true
apt-get update
apt-get install -y erlang-nox

# RabbitMQ repo and install
curl -fsSL https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey | apt-key add -
tee /etc/apt/sources.list.d/rabbitmq.list > /dev/null <<RABBIT_DEB
deb https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ $(lsb_release -cs) main
RABBIT_DEB
apt-get update
apt-get install -y rabbitmq-server

# Ensure data dirs and ownership
mkdir -p /var/lib/rabbitmq/mnesia /var/lib/rabbitmq/log
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq || true

# Configure rabbitmq env to use mounted dirs
cat > /etc/rabbitmq/rabbitmq-env.conf <<EOL
NODE_PORT=5672
MNESIA_DIR=/var/lib/rabbitmq/mnesia
LOG_BASE=/var/lib/rabbitmq/log
EOL

systemctl enable --now rabbitmq-server

# wait for rabbitmq to be ready
for i in $(seq 1 30); do
  if rabbitmqctl status >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# enable management plugin
rabbitmq-plugins enable rabbitmq_management

# create admin user if not exists
if ! rabbitmqctl list_users | grep -q '^mqadmin'; then
  rabbitmqctl add_user mqadmin "$(cat /run/secrets/mq_admin_password 2>/dev/null || echo 'SenhaTroca123')"
  rabbitmqctl set_user_tags mqadmin administrator
  rabbitmqctl set_permissions -p / mqadmin ".*" ".*" ".*"
fi

systemctl restart rabbitmq-server
EOF
}