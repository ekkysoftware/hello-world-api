provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "staging"
      ManagedBy   = "terraform"
      Stack       = "staging"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  artifact_bucket = var.artifact_bucket != "" ? var.artifact_bucket : "${var.project}-artifacts-${data.aws_caller_identity.current.account_id}"
}

check "account" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.expected_account_id
    error_message = "Credentials resolve to account ${data.aws_caller_identity.current.account_id}, expected ${var.expected_account_id}."
  }
}

module "app" {
  source = "../../modules/app"

  project         = var.project
  environment     = "staging"
  stage_name      = "dev"
  artifact_bucket = local.artifact_bucket

  log_retention_days = 14
  cors_allow_origins = var.cors_allow_origins
}
