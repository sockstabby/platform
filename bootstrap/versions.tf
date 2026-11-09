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

  # Bootstrap starts with LOCAL state (the bucket does not exist yet). After the first apply,
  # uncomment this block and run `terraform init -migrate-state` to move the state into the bucket.
  # Backend blocks cannot use variables, so the region is hard-coded here.
  # backend "s3" {
  #   bucket       = "modern-cloud-stack-tfstate-708884111549"
  #   key          = "bootstrap/terraform.tfstate"
  #   region       = "us-east-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }
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
