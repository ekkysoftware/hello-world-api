output "api_url" {
  value = module.app.api_url
}

output "function_name" {
  value = module.app.function_name
}

output "function_arn" {
  value = module.app.function_arn
}

output "api_id" {
  value = module.app.api_id
}

output "artifact_bucket" {
  value = local.artifact_bucket
}

output "region" {
  value = var.region
}
