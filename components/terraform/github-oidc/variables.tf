variable "region" {
  description = "AWS region. Whole project is single-region."
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project name: `project` tag and name prefix."
  type        = string
  default     = "modern-cloud-stack"
}

variable "environment" {
  description = "Environment name (debug | prod)."
  type        = string

  validation {
    condition     = contains(["debug", "prod"], var.environment)
    error_message = "environment must be debug or prod."
  }
}

variable "github_owner" {
  description = "GitHub owner (user/org) name. Informational; the trust uses the immutable owner ID."
  type        = string
  default     = "sockstabby"
}

variable "github_owner_id" {
  description = <<-EOT
    Numeric GitHub owner ID. Repos created after 2026-07-15 use immutable subject claims:
    sub = repo:OWNER@OWNER_ID/REPO@REPO_ID:... (GitHub docs, OIDC reference, "Immutable subject claims").
    Get it with: gh api users/<owner> --jq .id
  EOT
  type        = string
  default     = "17520257"
}

variable "github_environment" {
  description = "GitHub Environment name a deploy job must declare (`environment:`) to assume this role."
  type        = string
}
