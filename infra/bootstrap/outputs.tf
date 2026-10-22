output "account_id" {
  value = local.account_id
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.id
}

output "region" {
  value = var.region
}

# One pair per environment. Put staging's key in AWS_*_STAGING and prod's in
# AWS_*_PROD; each policy only reaches its own function.
output "deploy_access_key_ids" {
  value     = { for env, key in aws_iam_access_key.deploy : env => key.id }
  sensitive = true
}

output "deploy_secret_access_keys" {
  value     = { for env, key in aws_iam_access_key.deploy : env => key.secret }
  sensitive = true
}
