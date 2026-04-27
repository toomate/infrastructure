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