#!/bin/bash
# Toomate - Backup diario do banco MySQL.
# Renderizado a partir de backup_database.sh.tpl via templatefile() do Terraform.
# Cron disparado em 21:40 UTC = 18:40 BRT (vide /etc/cron.d/toomate-backup).

set -Eeuo pipefail

LOG=/var/log/toomate-backup.log
exec >> "$LOG" 2>&1

DB_NAME="${db_name}"
DB_ROOT_PASSWORD='${db_root_password}'
S3_BUCKET="${s3_bucket}"
SNS_TOPIC_ARN="${sns_topic_arn}"
AWS_REGION="${aws_region}"
CONTAINER_NAME="${container_name}"

DATA_ISO=$(date -u +%F)
BACKUP_FILE="toomate-$${DB_NAME}-$${DATA_ISO}.sql.gz"
BACKUP_PATH="/tmp/$${BACKUP_FILE}"

echo "===================================================================="
echo "[$(date -u +%FT%TZ)] Iniciando backup de $${DB_NAME} -> $${BACKUP_FILE}"

publicar_erro() {
  local etapa="$1"
  local exit_code="$${2:-1}"
  local mensagem="Falha no backup do banco Toomate ($${DATA_ISO}).
Etapa: $${etapa}
Exit code: $${exit_code}
Host: $(hostname)
Log: $${LOG}"
  echo "[ERRO] $${mensagem}"
  aws sns publish \
    --region "$${AWS_REGION}" \
    --topic-arn "$${SNS_TOPIC_ARN}" \
    --subject "[Toomate] Backup FALHOU $${DATA_ISO}" \
    --message "$${mensagem}" || echo "[ERRO] Falha tambem ao publicar no SNS."
  rm -f "$${BACKUP_PATH}"
  exit "$${exit_code}"
}

trap 'publicar_erro "trap inesperado (linha $LINENO)" $?' ERR

if ! docker exec "$${CONTAINER_NAME}" sh -c "mysqldump -uroot -p$${DB_ROOT_PASSWORD} --single-transaction --routines --triggers --events --databases $${DB_NAME}" 2>/tmp/mysqldump.err | gzip -9 > "$${BACKUP_PATH}"; then
  cat /tmp/mysqldump.err || true
  publicar_erro "mysqldump" 2
fi

if [ ! -s "$${BACKUP_PATH}" ]; then
  publicar_erro "arquivo de backup vazio" 3
fi

SIZE_MB=$(du -m "$${BACKUP_PATH}" | cut -f1)
echo "[$(date -u +%FT%TZ)] Dump gerado: $${BACKUP_PATH} ($${SIZE_MB} MB)"

if ! aws s3 cp "$${BACKUP_PATH}" "s3://$${S3_BUCKET}/$${BACKUP_FILE}" --region "$${AWS_REGION}"; then
  publicar_erro "upload S3" 4
fi
echo "[$(date -u +%FT%TZ)] Upload OK: s3://$${S3_BUCKET}/$${BACKUP_FILE}"

MENSAGEM_OK="Backup do banco Toomate concluido com sucesso.
Data: $${DATA_ISO}
Arquivo: s3://$${S3_BUCKET}/$${BACKUP_FILE}
Tamanho: $${SIZE_MB} MB
Host: $(hostname)"

aws sns publish \
  --region "$${AWS_REGION}" \
  --topic-arn "$${SNS_TOPIC_ARN}" \
  --subject "[Toomate] Backup OK $${DATA_ISO}" \
  --message "$${MENSAGEM_OK}" || echo "[AVISO] Backup ok, mas falha ao publicar notificacao SNS."

rm -f "$${BACKUP_PATH}"
echo "[$(date -u +%FT%TZ)] Backup finalizado com sucesso."
