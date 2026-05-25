import io
import os
import re
import unicodedata
import urllib.parse

import boto3
import numpy as np
import pandas as pd

s3 = boto3.client("s3")


def lambda_handler(event, context):
    record = event["Records"][0]["s3"]
    origem_bucket = record["bucket"]["name"]
    origem_key = urllib.parse.unquote_plus(record["object"]["key"])

    if not origem_key.lower().endswith(".csv"):
        print(f"Arquivo ignorado (não é CSV): {origem_key}")
        return {"statusCode": 200, "mensagem": "Arquivo ignorado"}

    destino_bucket = _env("DESTINO_BUCKET")
    destino_key = _montar_destino_key(origem_key)

    print(f"Lendo s3://{origem_bucket}/{origem_key}")
    resposta = s3.get_object(Bucket=origem_bucket, Key=origem_key)

    df = pd.read_csv(
        io.BytesIO(resposta["Body"].read()),
        sep=";",
        encoding="latin-1",
        dtype=str,
    )
    df.columns = [_normalizar_coluna(c) for c in df.columns]

    df_clean = _tratar(df)

    buffer = io.StringIO()
    df_clean.to_csv(buffer, index=False, sep=";")

    s3.put_object(
        Bucket=destino_bucket,
        Key=destino_key,
        Body=buffer.getvalue().encode("utf-8"),
        ContentType="text/csv; charset=utf-8",
        Metadata={
            "origem": origem_key,
            "linhas": str(len(df_clean)),
        },
    )

    print(f"CSV tratado salvo em s3://{destino_bucket}/{destino_key} | Linhas: {len(df_clean)}")

    return {
        "statusCode": 200,
        "origem": f"s3://{origem_bucket}/{origem_key}",
        "destino": f"s3://{destino_bucket}/{destino_key}",
        "linhas": len(df_clean),
    }


def _tratar(df: pd.DataFrame) -> pd.DataFrame:
    df_clean = df.copy()

    cols_removidas = [c for c in df_clean.columns if df_clean[c].nunique() <= 1]
    df_clean.drop(columns=cols_removidas, inplace=True)
    print(f"Colunas removidas: {cols_removidas}")

    df_clean["data_sinistro"] = pd.to_datetime(df_clean["data_sinistro"], format="%d/%m/%Y")

    df_clean["latitude"] = (
        df_clean["latitude"].replace("0,0", np.nan).str.replace(",", ".").astype(float)
    )
    df_clean["longitude"] = (
        df_clean["longitude"].replace("0,0", np.nan).str.replace(",", ".").astype(float)
    )

    for col in ["hora_sinistro", "tipo_local", "logradouro"]:
        df_clean[col] = df_clean[col].fillna("NAO DISPONIVEL")

    qtd_cols = [c for c in df_clean.columns if c.startswith("qtd_")]
    df_clean[qtd_cols] = df_clean[qtd_cols].fillna(0).astype(int)

    tp_bin_cols = [
        c for c in df_clean.columns
        if c.startswith("tp_sinistro_") and c != "tp_sinistro_primario"
    ]
    for col in tp_bin_cols:
        df_clean[col] = df_clean[col].apply(lambda x: 1 if x == "S" else 0).astype(int)

    return df_clean


def _normalizar_coluna(nome: str) -> str:
    sem_acento = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode("ascii")
    snake = re.sub(r"[^a-zA-Z0-9]+", "_", sem_acento.strip()).lower().strip("_")
    return snake or "coluna"


def _montar_destino_key(origem_key: str) -> str:
    partes = origem_key.rsplit("/", 1)
    nome_arquivo = partes[-1] if len(partes) > 1 else partes[0]
    pasta = partes[0] if len(partes) > 1 else ""

    nome_base = nome_arquivo[:-4] if nome_arquivo.lower().endswith(".csv") else nome_arquivo
    nome_tratado = f"{nome_base}_tratado.csv"

    return f"{pasta}/{nome_tratado}" if pasta else nome_tratado


def _env(key: str) -> str:
    value = os.environ.get(key, "").strip()
    if not value:
        raise EnvironmentError(f"Variável de ambiente obrigatória não definida: {key}")
    return value
