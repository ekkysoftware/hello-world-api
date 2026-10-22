terraform {
  required_version = ">= 1.11" # native S3 locking (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

# Local state on purpose: this stack creates the bucket that holds all other
# state. Never commit the resulting terraform.tfstate (it contains access keys).
