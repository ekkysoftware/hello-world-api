variable "region" {
  type    = string
  default = "ap-southeast-3"
}

variable "project" {
  type    = string
  default = "hello-world-api"
}

variable "expected_account_id" {
  description = "Guard against applying with the wrong AWS profile."
  type        = string
}

variable "artifact_bucket" {
  description = "Defaults to <project>-artifacts-<account id>, as created by bootstrap."
  type        = string
  default     = ""
}

variable "cors_allow_origins" {
  type    = list(string)
  default = []
}
