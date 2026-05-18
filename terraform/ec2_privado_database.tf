locals {
  backup_script = templatefile("${path.module}/scripts/backup_database.sh.tpl", {
    db_name          = var.db_name
    db_root_password = var.db_root_password
    s3_bucket        = aws_s3_bucket.backups.bucket
    sns_topic_arn    = aws_sns_topic.backup_alerts.arn
    aws_region       = "us-east-1"
    container_name   = "database"
  })
}

resource "aws_instance" "instancia_database_privada" {
  ami                         = "ami-0b6c6ebed2801a5cb"
  instance_type               = "t2.medium"
  key_name                    = "vockey"
  user_data_replace_on_change = true

  subnet_id = aws_subnet.subnet_toomate_privado.id

  vpc_security_group_ids = [aws_security_group.sg_privado_database.id]

  iam_instance_profile = aws_iam_instance_profile.lab_profile_db.name

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
  -e MYSQL_ROOT_PASSWORD=${var.db_root_password} \
  -e MYSQL_DATABASE=${var.db_name} \
  -e MYSQL_USER=${var.db_user} \
  -e MYSQL_PASSWORD=${var.db_password} \
  lucaspaessptech/toomate:database \
  --lower_case_table_names=1

# Instala AWS CLI v2 (necessario para s3 cp e sns publish)
if ! command -v aws >/dev/null 2>&1; then
  apt-get install -y unzip
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi

# Instala script de backup
mkdir -p /opt/toomate
chmod 700 /opt/toomate

cat > /opt/toomate/backup_database.sh <<'TOOMATE_BACKUP_EOF'
${local.backup_script}
TOOMATE_BACKUP_EOF

chmod 750 /opt/toomate/backup_database.sh
touch /var/log/toomate-backup.log
chown root:root /var/log/toomate-backup.log
chmod 640 /var/log/toomate-backup.log

# Configura cron diario (Linux usa UTC por padrao no Ubuntu)
cat > /etc/cron.d/toomate-backup <<CRON_EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Backup diario do MySQL Toomate -> S3 + SNS (${var.backup_cron_schedule} UTC)
${var.backup_cron_schedule} root /opt/toomate/backup_database.sh
CRON_EOF
chmod 644 /etc/cron.d/toomate-backup

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
