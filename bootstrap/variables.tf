variable "region" {
  description = "Region for the state bucket. The whole project runs in a single region."
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project name: used for the `project` tag and as a name prefix."
  type        = string
  default     = "modern-cloud-stack"
}

variable "spacelift_account_name" {
  description = "Spacelift account name (the <name> in https://<name>.app.spacelift.io)."
  type        = string
  default     = "sockstabby"
}

variable "spacelift_aws_principal" {
  description = "AWS account Spacelift SaaS assumes roles from. spacelift.io = 324880187172 (us.spacelift.io = 577638371743). Per Spacelift docs, checked 2026-11-09."
  type        = string
  default     = "324880187172"
}

variable "spacelift_stacks" {
  description = "Stack slugs allowed to assume the Spacelift role."
  type        = list(string)
  default = [
    "debug-network", "debug-github-oidc", "debug-eks",
    "prod-network", "prod-github-oidc", "prod-eks",
  ]
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep old state versions before S3 expires them."
  type        = number
  default     = 90
}
