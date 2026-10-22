provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id      = data.aws_caller_identity.current.account_id
  state_bucket    = "${var.project}-tfstate-${local.account_id}"
  artifact_bucket = "${var.project}-artifacts-${local.account_id}"
}

# ---------------------------------------------------------------- state bucket

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ------------------------------------------------------------- artifact bucket

resource "aws_s3_bucket" "artifacts" {
  bucket = local.artifact_bucket
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-deployed-zips"
    status = "Enabled"

    filter {
      prefix = "lambda/"
    }

    expiration {
      days = var.artifact_expiration_days
    }
  }
}

# Placeholder so the functions can be created before any CI run. Keys are
# content-addressed under lambda/, so this never collides with a real artifact.
data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/.bootstrap/placeholder.zip"

  source {
    filename = "hello_world_api/__init__.py"
    content  = ""
  }

  source {
    filename = "hello_world_api/main.py"
    content  = <<-PY
      import json


      def handler(event, context):
          return {
              "statusCode": 503,
              "headers": {"content-type": "application/json"},
              "body": json.dumps({"detail": "infrastructure only, no code deployed yet"}),
          }
    PY
  }
}

resource "aws_s3_object" "placeholder" {
  bucket        = aws_s3_bucket.artifacts.id
  key           = "bootstrap/placeholder.zip"
  source        = data.archive_file.placeholder.output_path
  source_hash   = data.archive_file.placeholder.output_base64sha256
  etag          = data.archive_file.placeholder.output_md5
  content_type  = "application/zip"
  cache_control = "no-store"
}

# ------------------------------------------------------------------ deploy IAM

resource "aws_iam_user" "deploy" {
  for_each = var.functions
  name     = "${var.project}-deploy-${each.key}"
}

resource "aws_iam_access_key" "deploy" {
  for_each = var.functions
  user     = aws_iam_user.deploy[each.key].name
}

resource "aws_iam_user_policy" "deploy" {
  for_each = var.functions
  name     = "ship-lambda-code"
  user     = aws_iam_user.deploy[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ArtifactsWrite"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.artifacts.arn}/lambda/*"
      },
      {
        Sid      = "ArtifactsList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.artifacts.arn
      },
      {
        Sid    = "OwnFunctionOnly"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:UpdateAlias",
          "lambda:GetAlias",
        ]
        Resource = "arn:aws:lambda:${var.region}:${local.account_id}:function:${each.value}*"
      },
    ]
  })
}
