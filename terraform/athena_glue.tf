resource "aws_s3_bucket" "athena_results" {
  bucket        = "toomate-athena-results-2026"
  force_destroy = true

  tags = {
    Name        = "athena-results"
    Environment = "Dev"
  }
}

resource "aws_glue_catalog_database" "toomate" {
  name        = "toomate"
  description = "Data catalog do toomate (raw + trusted)"
}

resource "aws_glue_crawler" "trusted" {
  name          = "toomate-trusted-crawler"
  database_name = aws_glue_catalog_database.toomate.name
  role          = data.aws_iam_role.lab_role.arn

  # Roda diariamente às 03:00 BRT (06:00 UTC) para capturar schema drift
  # e novas partições. Tabelas existentes detectam arquivos novos sem crawler.
  schedule = "cron(0 6 * * ? *)"

  s3_target {
    path = "s3://${aws_s3_bucket.toomate["trusted"].bucket}/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })
}

resource "aws_glue_crawler" "refined" {
  name          = "toomate-refined-crawler"
  database_name = aws_glue_catalog_database.toomate.name
  role          = data.aws_iam_role.lab_role.arn

  schedule = "cron(0 6 * * ? *)"

  s3_target {
    path = "s3://${aws_s3_bucket.toomate["refined"].bucket}/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
}

resource "aws_athena_workgroup" "toomate" {
  name          = "toomate"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
    }
  }
}

output "athena_workgroup" {
  value = aws_athena_workgroup.toomate.name
}

output "glue_database" {
  value = aws_glue_catalog_database.toomate.name
}

output "athena_results_bucket" {
  value = aws_s3_bucket.athena_results.bucket
}
