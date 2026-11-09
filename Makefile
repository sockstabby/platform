# Local helpers for the platform repo. Terraform comes from mise (reads .tool-versions).
.PHONY: check-tf-version
check-tf-version: ## Fail if required_version / .tool-versions drift from .spacelift/config.yml
	sh scripts/check-terraform-version.sh
