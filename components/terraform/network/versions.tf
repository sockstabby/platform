terraform {
  required_version = "1.17.1" # must equal TERRAFORM_VERSION in .spacelift/config.yml (drift-checked)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.72.0"
    }
  }
}
