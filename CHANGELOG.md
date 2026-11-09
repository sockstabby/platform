# Changelog

Releases of the `platform` repo. Tags cover both the reusable workflows and the OpenTofu code,
but only workflow changes affect app repos (Spacelift stacks track `main`, not tags).

Every entry says whether it is **breaking**. Breaking changes get a new major tag (`v2`, ...);
the floating `v1` tag is never moved onto a breaking change.

| Tag | Date | Breaking? | Changes |
|---|---|---|---|
| `v1.0.0` | 2026-11-09 | No (initial) | `reusable-build.yml` (build, optional push to GHCR), `reusable-chart-test.yml` (helm lint + kind install + `/healthz` smoke test) |
