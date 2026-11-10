terraform {
  # Partial backend: only `key` is supplied at init time, per stack:
  #   terraform init -backend-config=key=<env>/<component>.tfstate
  # (Spacelift: TF_CLI_ARGS_init; see docs/spacelift-setup.md)
  # Backend blocks can't use variables, so bucket and region are hard-coded here: this is the one
  # place the region is not taken from var.region.
  backend "s3" {
    bucket       = "modern-cloud-stack-tfstate-708884111549"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true # native S3 locking (Terraform >= 1.10)
  }
}
