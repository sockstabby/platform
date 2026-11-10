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

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Must be in STANDARD support (extended support costs 6x). Check: aws eks describe-cluster-versions --region us-east-2"
  type        = string
}

variable "endpoint_public_access_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach the public EKS API endpoint (still IAM-authenticated).
    Cannot be narrowed today: GitHub-hosted runners and Spacelift's public worker run outside the
    VPC from large, changing IP ranges. Production: private-only endpoint + self-hosted runners /
    Spacelift private worker inside the VPC.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}

variable "node_disk_size_gb" {
  type    = number
  default = 20
}

variable "admin_principal_arn" {
  description = "Human IAM principal given cluster-admin via access entry (so kubectl works for a person, not only the Spacelift creator role)."
  type        = string
}

variable "app_namespace" {
  description = "Namespace apps deploy into; the GitHub deploy role's access is scoped to it."
  type        = string
  default     = "apps"
}
