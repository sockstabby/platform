terraform {
  # Exact pin. Must equal TERRAFORM_VERSION in .spacelift/config.yml (the single version source);
  # scripts/check-terraform-version.sh fails CI and Spacelift runs if they drift.
  # Needs >= 1.10 for native S3 state locking (use_lockfile). 1.17.1 = latest stable, 2026-10-28.
  required_version = "1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.72.0" # latest in the Terraform registry as of 2026-11-09
    }
  }

  # Bootstrap's own state lives in the bucket it creates. First-ever run on a new account: comment
  # this block out, apply with local state, then uncomment and `terraform init -migrate-state`.
  # Backend blocks cannot use variables, so the region is hard-coded here (the one place it is).
  backend "s3" {
    bucket       = "modern-cloud-stack-tfstate-708884111549"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true # native S3 locking (Terraform >= 1.10), no DynamoDB table
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project      = var.project
      environment  = "global"
      "managed-by" = "terraform"
    }
  }
}
