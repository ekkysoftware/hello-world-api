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

  # Terraform temporarily owns the code so `apply` can ship this build to both
  # functions. Restore the lifecycle block in infra/README.md before CI deploys,
  # otherwise every apply reverts CI's deploy.
  filename         = var.source_zip
  source_code_hash = filebase64sha256(var.source_zip)

  environment {
    variables = {
      APP_ENV = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}
