output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "function_role_arn" {
  value = aws_iam_role.lambda.arn
}

# Trailing slash matters: the smoke test appends ?name=... to the bare URL.
output "api_url" {
  value = "${aws_apigatewayv2_api.this.api_endpoint}/${aws_apigatewayv2_stage.this.name}/"
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "api_stage" {
  value = aws_apigatewayv2_stage.this.name
}

output "lambda_log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}

output "api_log_group" {
  value = aws_cloudwatch_log_group.api.name
}
