terraform {
  # >= 1.10 for native S3 state locking (use_lockfile). Verified latest: 1.13.9 (2026-11-05).
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.72.0" # latest in the OpenTofu registry as of 2026-11-09
    }
  }

  # Bootstrap starts with LOCAL state (the bucket does not exist yet). After the first apply,
  # uncomment this block and run `tofu init -migrate-state` to move the state into the bucket.
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
      "managed-by" = "opentofu"
    }
  }
}
