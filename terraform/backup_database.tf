# ---------------------------------------------------------------------------
# Backup automatizado do MySQL Toomate
#   - Bucket S3 dedicado com lifecycle de retencao
#   - SNS Topic + subscription para notificar o administrador
#   - Instance Profile reaproveitando a LabRole para a EC2 do banco
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "backups" {
  bucket        = "toomate-db-backups-2026"
  force_destroy = true

  tags = {
    Name        = "toomate-db-backups"
    Environment = "Dev"
    Purpose     = "MySQL daily backups"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expira-backups-antigos"
    status = "Enabled"

    filter {}

    expiration {
      days = var.backup_retention_days
    }
  }
}

resource "aws_sns_topic" "backup_alerts" {
  name = "toomate-backup-alerts"

  tags = {
    Name        = "toomate-backup-alerts"
    Environment = "Dev"
  }
}

resource "aws_sns_topic_subscription" "admin_email" {
  topic_arn = aws_sns_topic.backup_alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

resource "aws_iam_instance_profile" "lab_profile_db" {
  name = "toomate-lab-profile-db-backup"
  role = data.aws_iam_role.lab_role.name
}

output "backup_bucket" {
  description = "Bucket S3 onde os backups diarios sao armazenados"
  value       = aws_s3_bucket.backups.bucket
}

output "backup_sns_topic" {
  description = "ARN do SNS Topic que dispara notificacoes de backup"
  value       = aws_sns_topic.backup_alerts.arn
}

output "backup_admin_email" {
  description = "Email do admin inscrito no topic (confirmar via link no primeiro email)"
  value       = var.admin_email
}
