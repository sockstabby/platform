# Changelog

Releases of the `platform` repo. Tags cover both the reusable workflows and the Terraform code,
but only workflow changes affect app repos (Spacelift stacks track `main`, not tags).

Every entry says whether it is **breaking**. Breaking changes get a new major tag (`v2`, ...);
the floating `v1` tag is never moved onto a breaking change.

| Tag | Date | Breaking? | Changes |
|---|---|---|---|
| `v1.1.0` | 2026-11-09 | No (new workflow) | Adds `reusable-deploy.yml`: OIDC role from the caller's GitHub Environment (`AWS_ROLE_ARN`, `EKS_CLUSTER_NAME`), `aws eks update-kubeconfig`, `helm upgrade --install --rollback-on-failure --wait` (Helm 4's replacement for `--atomic`). Existing inputs of v1.0.0 workflows unchanged. Also includes the infra-only changes since v1.0.0: OpenTofu → HashiCorp Terraform 1.17.1 via Spacelift's Custom workflow tool (`.spacelift/`), version drift check, network/github-oidc/eks components and debug stacks. |
| `v1.0.0` | 2026-11-09 | No (initial) | `reusable-build.yml` (build, optional push to GHCR), `reusable-chart-test.yml` (helm lint + kind install + `/healthz` smoke test) |
