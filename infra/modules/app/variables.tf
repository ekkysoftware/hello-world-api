variable "project" {
  type = string
}

variable "environment" {
  description = "staging or prod. Drives the function name."
  type        = string
}

variable "stage_name" {
  description = "API Gateway stage, which is the URL path prefix (dev or api)."
  type        = string
}

variable "artifact_bucket" {
  description = "Bucket created by the bootstrap stack."
  type        = string
}

variable "bootstrap_key" {
  description = "Placeholder object used only to create the function; CI owns the code afterwards."
  type        = string
  default     = "bootstrap/placeholder.zip"
}

variable "runtime" {
  type    = string
  default = "python3.14"
}

variable "architecture" {
  description = "Must match scripts/build_lambda.sh (x86_64-manylinux2014 wheels)."
  type        = string
  default     = "x86_64"
}

variable "memory_size" {
  type    = number
  default = 512
}

variable "timeout" {
  description = "Seconds. Keep well under the 29s HTTP API integration limit."
  type        = number
  default     = 10
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "throttling_burst_limit" {
  type    = number
  default = 50
}

variable "throttling_rate_limit" {
  type    = number
  default = 25
}

variable "cors_allow_origins" {
  description = "Leave empty if FastAPI handles CORS; setting both duplicates headers."
  type        = list(string)
  default     = []
}
