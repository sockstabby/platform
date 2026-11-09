# Changelog

Releases of the `platform` repo. Tags cover both the reusable workflows and the Terraform code,
but only workflow changes affect app repos (Spacelift stacks track `main`, not tags).

Every entry says whether it is **breaking**. Breaking changes get a new major tag (`v2`, ...);
the floating `v1` tag is never moved onto a breaking change.

| Tag | Date | Breaking? | Changes |
|---|---|---|---|
| _Unreleased_ | 2026-11-09 | No (infra only) | IaC tool switched from OpenTofu to HashiCorp Terraform 1.17.1, run by Spacelift's Custom workflow tool (`.spacelift/`). Version drift check added. No reusable-workflow changes, so no tag. |
| `v1.0.0` | 2026-11-09 | No (initial) | `reusable-build.yml` (build, optional push to GHCR), `reusable-chart-test.yml` (helm lint + kind install + `/healthz` smoke test) |
