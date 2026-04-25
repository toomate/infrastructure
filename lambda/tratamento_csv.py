import csv
import io
import os
import re
import unicodedata
import urllib.parse
from datetime import datetime

import boto3

s3 = boto3.client("s3")

DELIMITADOR_ENTRADA = ";"
DELIMITADOR_SAIDA = ";"
ENCODING_ENTRADA = "latin-1"

COLUNAS_DECIMAL_BR = {"latitude", "longitude"}
COLUNAS_INTEIRAS = {"numero_logradouro"}
SENTINELAS_NULAS = {"NAO DISPONIVEL", "NAO INFORMADO", "N/A", "NA", "-"}


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
    conteudo_bruto = resposta["Body"].read().decode(ENCODING_ENTRADA)

    linhas_entrada, linhas_saida, duplicatas = _tratar_csv(conteudo_bruto)

    s3.put_object(
        Bucket=destino_bucket,
        Key=destino_key,
        Body=linhas_saida.encode("utf-8"),
        ContentType="text/csv; charset=utf-8",
        Metadata={
            "origem": origem_key,
            "linhas_originais": str(linhas_entrada),
            "duplicatas_removidas": str(duplicatas),
        },
    )

    print(
        f"CSV tratado salvo em s3://{destino_bucket}/{destino_key} | "
        f"Linhas originais: {linhas_entrada} | Duplicatas removidas: {duplicatas}"
    )

    return {
        "statusCode": 200,
        "origem": f"s3://{origem_bucket}/{origem_key}",
        "destino": f"s3://{destino_bucket}/{destino_key}",
        "linhas_originais": linhas_entrada,
        "duplicatas_removidas": duplicatas,
        "linhas_salvas": linhas_entrada - duplicatas,
    }


def _tratar_csv(conteudo: str) -> tuple[int, str, int]:
    reader = csv.DictReader(io.StringIO(conteudo), delimiter=DELIMITADOR_ENTRADA)

    if not reader.fieldnames:
        raise ValueError("CSV sem cabeçalho ou vazio")

    colunas_normalizadas = [_normalizar_coluna(c) for c in reader.fieldnames]
    linhas_entrada = 0
    vistas: set[tuple] = set()
    linhas_limpas: list[dict] = []

    for linha in reader:
        valores_limpos = {
            col_norm: _limpar_valor(col_norm, val)
            for col_norm, val in zip(colunas_normalizadas, linha.values())
        }

        if all(v == "" for v in valores_limpos.values()):
            continue

        linhas_entrada += 1
        chave = tuple(valores_limpos[c] for c in colunas_normalizadas)
        if chave in vistas:
            continue

        vistas.add(chave)
        linhas_limpas.append(valores_limpos)

    duplicatas = linhas_entrada - len(linhas_limpas)

    saida = io.StringIO()
    writer = csv.DictWriter(
        saida,
        fieldnames=colunas_normalizadas,
        delimiter=DELIMITADOR_SAIDA,
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(linhas_limpas)

    return linhas_entrada, saida.getvalue(), duplicatas


def _normalizar_coluna(nome: str) -> str:
    sem_acento = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode("ascii")
    snake = re.sub(r"[^a-zA-Z0-9]+", "_", sem_acento.strip()).lower().strip("_")
    return snake or "coluna"


def _limpar_valor(coluna: str, valor: str) -> str:
    v = (valor or "").strip()
    if not v:
        return ""

    sem_acento = unicodedata.normalize("NFKD", v).encode("ascii", "ignore").decode("ascii")
    if sem_acento.upper() in SENTINELAS_NULAS:
        return ""

    if coluna in COLUNAS_DECIMAL_BR:
        return _tratar_decimal(v)

    if coluna in COLUNAS_INTEIRAS:
        return _tratar_inteiro(v)

    if coluna == "data_sinistro":
        return _tratar_data(v)

    return v


def _tratar_decimal(valor: str) -> str:
    normalizado = valor.replace(",", ".")
    try:
        numero = float(normalizado)
    except ValueError:
        return ""
    if numero == 0.0:
        return ""
    return normalizado


def _tratar_inteiro(valor: str) -> str:
    try:
        return str(int(float(valor.replace(",", "."))))
    except ValueError:
        return valor


def _tratar_data(valor: str) -> str:
    for formato in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y"):
        try:
            return datetime.strptime(valor, formato).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return valor


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
