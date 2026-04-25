data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../lambda"
  output_path = ".terraform/relatorio_vencimentos.zip"
}

data "archive_file" "lambda_zip_tratamento" {
  type        = "zip"
  source_dir  = "../lambda"
  output_path = ".terraform/tratamento_csv.zip"
}

resource "aws_security_group" "sg_lambda" {
  name        = "sg_lambda_relatorio"
  description = "Security group da Lambda de relatorio de vencimentos"
  vpc_id      = aws_vpc.vpc_toomate.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_lambda_relatorio"
  }
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ---------------------------------------------------------------------------
# Lambda
# ---------------------------------------------------------------------------
resource "aws_lambda_function" "relatorio_vencimentos" {
  function_name    = "toomate-relatorio-vencimentos"
  role             = data.aws_iam_role.lab_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime     = "python3.12"
  handler     = "relatorio_vencimentos.lambda_handler"
  timeout     = 60
  memory_size = 256

  vpc_config {
    subnet_ids         = [aws_subnet.subnet_toomate_privado.id, aws_subnet.subnet_toomate_privado_2.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }

  environment {
    variables = {
      DB_HOST     = aws_instance.instancia_database_privada.private_ip
      DB_PORT     = tostring(var.database_porta)
      DB_NAME     = var.db_name
      DB_USER     = var.db_user
      DB_PASSWORD = var.db_password
      S3_BUCKET   = aws_s3_bucket.toomate["refined"].bucket
      S3_PREFIX   = var.s3_prefix
    }
  }
}

resource "aws_cloudwatch_event_rule" "diario" {
  name                = "toomate-relatorio-vencimentos-diario"
  description         = "Dispara a Lambda de relatório de vencimentos todo dia às 06h BRT"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.diario.name
  target_id = "relatorio-vencimentos"
  arn       = aws_lambda_function.relatorio_vencimentos.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.relatorio_vencimentos.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.diario.arn
}

resource "aws_lambda_function" "tratamento_csv" {
  function_name    = "toomate-tratamento-csv"
  role             = data.aws_iam_role.lab_role.arn
  filename         = data.archive_file.lambda_zip_tratamento.output_path
  source_code_hash = data.archive_file.lambda_zip_tratamento.output_base64sha256

  runtime     = "python3.12"
  handler     = "tratamento_csv.lambda_handler"
  timeout     = 120
  memory_size = 256

  environment {
    variables = {
      DESTINO_BUCKET = aws_s3_bucket.toomate["trusted"].bucket
    }
  }

  tags = {
    Name = "toomate-tratamento-csv"
  }
}

resource "aws_lambda_permission" "s3_raw" {
  statement_id  = "AllowS3RawInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tratamento_csv.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.toomate["raw"].arn
}

resource "aws_s3_bucket_notification" "raw_csv_trigger" {
  bucket = aws_s3_bucket.toomate["raw"].id

  lambda_function {
    lambda_function_arn = aws_lambda_function.tratamento_csv.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.s3_raw]
}
