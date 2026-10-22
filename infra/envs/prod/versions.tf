terraform {
  required_version = ">= 1.11"

  backend "s3" {
    bucket       = "hello-world-api-tfstate-084139690943"
    key          = "prod/terraform.tfstate"
    region       = "ap-southeast-3"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
  }
}
