locals {
  function_name = "${var.project}-${var.environment}"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  runtime       = var.runtime
  handler       = "hello_world_api.main.handler"
  architectures = [var.architecture]
  memory_size   = var.memory_size
  timeout       = var.timeout

  s3_bucket = var.artifact_bucket
  s3_key    = var.bootstrap_key

  environment {
    variables = {
      APP_ENV = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  # CI deploys code with `aws lambda update-function-code`. Without this,
  # `terraform apply` would silently revert production to the placeholder.
  lifecycle {
    ignore_changes = [s3_bucket, s3_key, s3_object_version, filename, source_code_hash]
  }
}
