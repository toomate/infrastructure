locals {
  buckets = {
    raw     = "toomate-raw-2026"
    trusted = "toomate-trusted-2026"
    refined = "toomate-client-2026"
  }
}

resource "aws_s3_bucket" "toomate" {
  for_each = local.buckets

  bucket = each.value

  force_destroy = true

  tags = {
    Name        = each.key
    Environment = "Dev"
  }
}

resource "aws_s3_bucket" "comprovantes" {
  bucket = "toomate-comprovantes"

  force_destroy = true

  tags = {
    Name        = "comprovantes"
    Environment = "Dev"
  }
}

# Comprovantes sao documentos sensiveis: bloqueia qualquer acesso publico.
resource "aws_s3_bucket_public_access_block" "comprovantes" {
  bucket = aws_s3_bucket.comprovantes.id

  block_public_acls       = true
  block_public_policy      = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}