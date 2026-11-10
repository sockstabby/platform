terraform {
  required_version = "1.17.1" # must equal TERRAFORM_VERSION in .spacelift/config.yml (drift-checked)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.72.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.5.0"
    }
    # Required by the EKS module (>= 4.0 / >= 0.9); pinned here so the lock file is deterministic.
    tls = {
      source  = "hashicorp/tls"
      version = "4.4.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.14.2"
    }
  }
}
