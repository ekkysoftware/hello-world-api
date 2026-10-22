variable "region" {
  description = "AWS region for every resource, including the buckets."
  type        = string
  default     = "ap-southeast-3"
}

variable "project" {
  description = "Name prefix for buckets, users and functions."
  type        = string
  default     = "hello-world-api"
}

variable "functions" {
  description = "Deploy identity per environment, mapped to the Lambda function name it may update."
  type        = map(string)
  default = {
    staging = "hello-world-api-staging"
    prod    = "hello-world-api-prod"
  }
}

variable "artifact_expiration_days" {
  description = "How long deployed zips stay available as rollback targets."
  type        = number
  default     = 90
}
