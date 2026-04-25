import json
import os
from datetime import date

import boto3
import pymysql
import pymysql.cursors

QUERY = """
    SELECT
        l.idLote,
        i.nome          AS nomeInsumo,
        m.nomeMarca,
        l.quantidadeMedida,
        i.unidadeMedida,
        l.dataValidade
    FROM Lote l
    JOIN Marca  m ON l.fkMarca  = m.idMarca
    JOIN Insumo i ON m.fkInsumo = i.idInsumo
    WHERE l.quantidadeMedida > 0
    ORDER BY l.dataValidade
"""


def lambda_handler(event, context):
    hoje = date.today()

    conn = pymysql.connect(
        host=_env("DB_HOST"),
        port=int(os.environ.get("DB_PORT", "3306")),
        database=os.environ.get("DB_NAME", "toomate"),
        user=_env("DB_USER"),
        password=_env("DB_PASSWORD"),
        cursorclass=pymysql.cursors.DictCursor,
    )

    try:
        with conn.cursor() as cursor:
            cursor.execute(QUERY)
            rows = cursor.fetchall()
    finally:
        conn.close()

    lotes = []
    vencidos = vencem_hoje = proximos_7_dias = 0

    for row in rows:
        data_validade = row["dataValidade"]
        if isinstance(data_validade, str):
            data_validade = date.fromisoformat(data_validade)

        dias_restantes = (data_validade - hoje).days
        status = _calcular_status(dias_restantes)

        if status == "Vencido":
            vencidos += 1
        if status == "Vence Logo":
            proximos_7_dias += 1
        if data_validade == hoje:
            vencem_hoje += 1

        qtd = float(row["quantidadeMedida"])
        lotes.append({
            "id_lote":        row["idLote"],
            "insumo":         row["nomeInsumo"],
            "marca":          row["nomeMarca"],
            "estoque_atual":  f"{qtd:.2f}{row['unidadeMedida']}",
            "data_validade":  data_validade.isoformat(),
            "dias_restantes": dias_restantes,
            "status":         status,
        })

    kpis = {
        "vencidos":        vencidos,
        "vencem_hoje":     vencem_hoje,
        "proximos_7_dias": proximos_7_dias,
    }

    relatorio = {
        "data_geracao": hoje.isoformat(),
        "kpis":         kpis,
        "total_lotes":  len(lotes),
        "lotes":        lotes,
    }

    s3_prefix = os.environ.get("S3_PREFIX", "relatorios/vencimentos")
    s3_key = f"{s3_prefix}/{hoje.isoformat()}.json"
    s3_bucket = _env("S3_BUCKET")

    boto3.client("s3").put_object(
        Bucket=s3_bucket,
        Key=s3_key,
        Body=json.dumps(relatorio, indent=2, ensure_ascii=False).encode("utf-8"),
        ContentType="application/json",
    )

    print(f"Relatório salvo em s3://{s3_bucket}/{s3_key} | KPIs: {kpis} | Total lotes: {len(lotes)}")

    return {
        "statusCode":  200,
        "s3_key":      s3_key,
        "kpis":        kpis,
        "total_lotes": len(lotes),
    }


def _calcular_status(dias_restantes: int) -> str:
    if dias_restantes < 0:
        return "Vencido"
    if dias_restantes <= 7:
        return "Vence Logo"
    return "No Prazo"


def _env(key: str) -> str:
    value = os.environ.get(key, "").strip()
    if not value:
        raise EnvironmentError(f"Variável de ambiente obrigatória não definida: {key}")
    return value
