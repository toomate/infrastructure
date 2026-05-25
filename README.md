# Toomate — Infrastructure

Repositório de infraestrutura do projeto Toomate. Contém o provisionamento da nuvem (Terraform/AWS), o ambiente local de desenvolvimento (Docker Compose), as funções Lambda da pipeline de dados e a stack de observabilidade.

---

## Visão geral

A solução é composta por:

- **Backend Java/Spring** com MySQL, Redis e RabbitMQ
- **Microserviço de notificações** consumidor do RabbitMQ
- **Integração WAHA** (WhatsApp HTTP API)
- **Pipeline de dados em três camadas** no S3 (raw → trusted → refined)
- **Backup automatizado** do MySQL em S3 com retenção configurável e alertas via SNS
- **Catálogo de dados** com AWS Glue + consulta via Athena
- **Observabilidade** com Prometheus, Grafana e exporters

Toda a infra na AWS é provisionada via Terraform, e o ambiente local sobe via `docker compose`.

---

## Stack

| Camada | Tecnologia |
|---|---|
| IaC | Terraform `~> 1.14`, AWS provider `~> 5.92` |
| Cloud | AWS (us-east-1) — EC2, VPC, S3, Lambda, Glue, Athena, SNS, CloudWatch |
| Runtime local | Docker Compose |
| Aplicação | Spring Boot, MySQL 8, Redis 7, RabbitMQ 4.2 |
| Data pipeline | Python 3.12, pandas (AWS SDK for pandas layer), boto3 |
| Observabilidade | Prometheus, Grafana OSS, mysqld-exporter, rabbitmq_prometheus |

---

## Estrutura do repositório

```
infrastructure/
├── compose.yaml                # Ambiente local completo (backend + DB + obs + msg)
├── terraform/                  # Provisionamento AWS
│   ├── main.tf                 # Provider + versões
│   ├── variaveis.tf            # Variáveis globais
│   ├── vpc.tf, route_table.tf  # Rede
│   ├── ec2_*.tf                # Instâncias (publica, backend, db, rabbitmq, obs, analise)
│   ├── security_group_*.tf     # SGs por camada
│   ├── load_balancer.tf        # ALB
│   ├── s3.tf                   # Buckets raw / trusted / refined
│   ├── lambda.tf               # Funções Lambda + triggers
│   ├── athena_glue.tf          # Catálogo + workgroup do Athena
│   └── backup_database.tf      # Backup MySQL + SNS
├── lambda/                     # Código das funções
│   ├── tratamento_csv.py       # ETL raw → trusted (pandas)
│   └── relatorio_vencimentos.py # Relatório agregado → refined
├── grafana/                    # Dashboards e datasources provisionados
├── prometheus/prometheus.yml   # Targets de scrape
├── redis/                      # Config do Redis
└── localstack/                 # Stack local para simular AWS
```

---

## Pré-requisitos

- Docker + Docker Compose
- Terraform `1.14+`
- AWS CLI configurada (credenciais em `~/.aws/credentials` — usado pelo Terraform e pelo container do Grafana)
- Conta AWS com permissão na role usada (em ambiente AWS Academy, o código usa `LabRole` por padrão)

---

## Ambiente local

Sobe a stack completa de desenvolvimento:

```bash
docker compose up -d
```

| Serviço | URL | Notas |
|---|---|---|
| Backend Spring | http://localhost:8080 | API principal |
| Swagger | http://localhost:8080/swagger-ui.html | Documentação |
| MySQL | localhost:3306 | user/pass: `root` / `root` |
| Redis | localhost:6379 | |
| RedisInsight | http://localhost:5540 | UI do Redis |
| RabbitMQ UI | http://localhost:15672 | user/pass: `myuser` / `secret` |
| WAHA | http://localhost:3000 | WhatsApp HTTP API |
| Microserviço notif | http://localhost:8182 | Consumer do RabbitMQ |
| Prometheus | http://localhost:9090 | |
| Grafana | http://localhost:3001 | admin/admin |

Para parar tudo:

```bash
docker compose down
```

Para zerar volumes (perde dados do MySQL, Redis, sessões WAHA, etc.):

```bash
docker compose down -v
```

---

## Provisionamento AWS

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Recursos principais criados:

- **VPC** `10.0.0.0/23` com subnets pública e privada em duas AZs
- **EC2 pública** para frontend, **EC2 privada** de backend, banco, RabbitMQ e observability
- **Application Load Balancer** público
- **Buckets S3**: `toomate-raw-2026`, `toomate-trusted-2026`, `toomate-client-2026`, `toomate-athena-results-2026`, `toomate-db-backups-2026`
- **Lambdas**: `toomate-relatorio-vencimentos` (agendada via EventBridge) e `toomate-tratamento-csv` (disparada por upload no raw)
- **Glue Catalog** + **Athena workgroup** apontando para os dados em S3
- **SNS topic** + assinatura por e-mail para alertas de backup

### Variáveis sensíveis

Senhas (`db_password`, `db_root_password`) e e-mail do admin estão em [terraform/variaveis.tf](terraform/variaveis.tf) com valores default. Em produção, sobrescreva via `terraform.tfvars` ou variáveis de ambiente `TF_VAR_*`.

### Destruir

```bash
terraform destroy
```

---

## Pipeline de dados

Arquitetura em três camadas, padrão **medallion**:

```
[upload manual / app]
        │
        ▼
  S3: toomate-raw-2026
        │   (trigger ObjectCreated:*.csv)
        ▼
  Lambda: tratamento_csv
    - lê CSV (delimitador ;, encoding latin-1)
    - normaliza colunas (snake_case, sem acento)
    - remove colunas de cardinalidade 1
    - tipa data, lat/long, qtd_*, tp_sinistro_*
    - deduplica e remove vazios
        │
        ▼
  S3: toomate-trusted-2026
        │
        ▼
  Glue Catalog → Athena → Grafana / análises
```

A Lambda `relatorio_vencimentos` é independente: roda diariamente (EventBridge), consulta o MySQL e grava um JSON agregado direto no bucket **refined** (`toomate-client-2026`).

### Adicionando um novo CSV

Fluxo completo, do upload até a query no Athena:

```bash
# 1. Sobe o CSV no bucket raw — dispara a Lambda automaticamente
aws s3 cp meu_arquivo.csv s3://toomate-raw-2026/sinistros/

# 2. (opcional) Acompanha o processamento da Lambda
aws logs tail /aws/lambda/toomate-tratamento-csv --follow

# 3. Confere o arquivo tratado no bucket trusted
aws s3 ls s3://toomate-trusted-2026/sinistros/

# 4. Roda o crawler do Glue pra atualizar o catálogo
aws glue start-crawler --name toomate-trusted-crawler

# 5. Acompanha o status do crawler
aws glue get-crawler --name toomate-trusted-crawler --query "Crawler.State"

# 6. Consulta no Athena (depois do crawler terminar)
aws athena start-query-execution \
  --query-string "SELECT * FROM toomate.sinistros LIMIT 10" \
  --work-group toomate
```

> **Nota sobre o crawler:** os crawlers (`toomate-trusted-crawler` e `toomate-refined-crawler`) rodam **automaticamente uma vez por dia às 03:00 BRT**. Para o Athena, isso é suficiente — depois que a tabela existe no catálogo, novos arquivos na mesma pasta são lidos sem precisar re-rodar o crawler. A execução diária só é necessária para capturar **mudanças de schema** (coluna nova, tipo diferente) ou **novas partições** (pastas novas tipo `ano=2026/mes=01/`). O comando `aws glue start-crawler` da etapa 4 só é necessário se você quiser ver os dados antes do próximo run agendado.

---

## Observabilidade

A stack expõe métricas via:

- **mysqld-exporter** (porta 9104) — MySQL
- **rabbitmq_prometheus** (porta 15692) — RabbitMQ
- **Actuator do Spring** (porta 8080) — backend
- **Microserviço notif** (porta 8182)

O Prometheus faz scrape de todos e o Grafana provisiona dashboards via [grafana/provisioning/](grafana/provisioning/). A datasource do Athena também é provisionada e usa as credenciais montadas de `~/.aws`.

---

## Backup do MySQL

Cron diário (default `18:40 BRT`) na EC2 do banco:

1. `mysqldump` da base `toomate`
2. Upload para `s3://toomate-db-backups-2026/<data>/`
3. Lifecycle do bucket apaga após `backup_retention_days` (default 30)
4. SNS notifica o admin em caso de falha

Parâmetros configuráveis em [terraform/variaveis.tf](terraform/variaveis.tf).

---

## Comandos úteis

```bash
# Logs do backend
docker logs -f toomate_backend

# Acesso ao MySQL local
docker exec -it toomate_mysql mysql -u root -proot toomate

# Re-empacotar e re-deployar uma Lambda
cd terraform && terraform apply -target=aws_lambda_function.tratamento_csv

# Forçar re-upload de objeto S3 gerenciado pelo Terraform
terraform taint aws_s3_object.<nome>
terraform apply

# Testar Lambda localmente (requer boto3, pandas, numpy)
python lambda/test.py
```

---

## Equipe

Projeto acadêmico da SPTech — segundo ano.
