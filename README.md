# platform

> Full README (architecture, design decisions, costs) is written in Phase 7.

## Reusable workflow versioning

App repos call the workflows in this repo by **major tag**, e.g.
`sockstabby/platform/.github/workflows/reusable-build.yml@v1`.

Why: a GitHub template is copied once. Repos created from it never receive later template
changes, but a workflow ref can be bumped. Keeping all CI/CD logic here and only thin callers in
the app repos means a fix lands once and every app picks it up.

**Tags**
- Every release gets a semver tag: `v1.0.0`, `v1.1.0`, `v1.1.1`, ...
- A floating major tag (`v1`) points at the latest `v1.x.y`.

**Non-breaking changes** (new *optional* inputs, bug fixes, internal refactors): release a new
minor/patch tag and move `v1` to it. Existing apps pick up the change automatically.

**Breaking changes** (removing/renaming inputs, secrets or outputs; making an input required;
changing deploy behaviour an app relies on): release `v2.0.0` and create a new `v2` tag.
**Never move `v1` to a breaking change.** Apps opt in by changing `@v1` to `@v2`.

**Deprecation:** keep `v1` working until every app repo has moved off it. Announce deprecations
here and in the workflow output with `::warning::`.

**Scope:** infra and workflow code share this repo, so one tag covers both. Workflow-only
releases are fine; Spacelift stacks track `main`, not tags, so they are unaffected.

The template's `ci.yml`, `deploy-debug.yml` and `deploy-prod.yml` always reference the current
major tag. Every release is recorded in [CHANGELOG.md](CHANGELOG.md).

**Releasing** (maintainer):
```sh
git tag -a v1.1.0 -m "v1.1.0"        # immutable release tag
git tag -fa v1 -m "v1 -> v1.1.0"     # move the floating major tag (non-breaking only!)
git push origin v1.1.0 && git push -f origin v1
```

**Pinning third-party actions:** inside these workflows, every third-party action is pinned to a
full commit SHA (with a `# vX.Y.Z` comment), because tags can be moved by their owners.

**Private repos:** these repos are public, so cross-repo `uses:` just works. If `platform` were
private, it would need *Settings → Actions → General → Access* set to allow other repos to use
its workflows.
