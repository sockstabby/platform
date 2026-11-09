# bootstrap

Applied **once, locally** with Terraform 1.17.1 (installed by `mise` from `../.tool-versions`), by a human (not through Spacelift). It creates the things everything
else depends on:

- S3 state bucket `modern-cloud-stack-tfstate-<account-id>` (versioned, SSE-S3, public access blocked, TLS-only)
- The account-global GitHub Actions OIDC provider
- The IAM role Spacelift assumes (`modern-cloud-stack-spacelift`)

```sh
export AWS_PROFILE=mod-cloud-stack AWS_REGION=us-east-2
terraform init
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan

# then move this state into the bucket it just created:
#   uncomment the backend "s3" block in versions.tf
terraform init -migrate-state
```

Destroying is covered in `../docs/teardown.md` (the bucket must be emptied, all versions, first).
