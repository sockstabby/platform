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

variable "vpc_cidr" {
  description = "VPC CIDR. Must not overlap between environments."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Two public subnets (NAT gateway + IGW routing only; nothing else runs here)."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnets (one per AZ)."
  }
}

variable "private_subnet_cidrs" {
  description = "Two private subnets for EKS nodes."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnets (one per AZ)."
  }
}
