# platform

> Full README (architecture, design decisions, costs) is written in Phase 7.

## Design note: the `apps` namespace is created by the eks component

The eks component configures the `kubernetes` provider from the cluster it creates (token from
`aws_eks_cluster_auth`) and creates the `apps` namespace, which the GitHub deploy role's access entry
is scoped to (`AmazonEKSEditPolicy`, namespace `apps`). Configuring a provider from a cluster in the
same configuration is a known caveat: it works for create and destroy but can fail if the cluster
has to be replaced. Accepted here for one namespace; production would manage namespaces separately
(GitOps / a second component).

## Design decision: Terraform via Spacelift's Custom workflow

**Choice:** HashiCorp Terraform 1.17.1 (exact pin), run by Spacelift through its *Custom* workflow
tool (`.spacelift/workflow.yml`), with a hook (`.spacelift/install-terraform.sh`) that downloads
the pinned release and verifies its SHA256 checksum before every phase that runs Terraform.

**Why Custom is needed:** Spacelift supplies only open-source Terraform (MPL 2.0, up to 1.5.7) and
OpenTofu. Releases after 1.5.7 are under the Business Source License 1.1, so Spacelift won't
download them for us. We need >= 1.10 for native S3 state locking (`use_lockfile`), so we bring
our own binary.

**Licensing:** my reading of BSL 1.1 and
[HashiCorp's licensing FAQ](https://www.hashicorp.com/license-faq) is that using Terraform to
manage your own infrastructure is permitted, and that the restriction targets products offered
to third parties that compete with HashiCorp's (see the FAQ's questions on "competitive offering"
and on hosting internally). This is not a legal conclusion; anyone adopting this pattern
commercially should check with their own counsel.

**Costs of this choice:**
- We own a supply-chain step: the hook downloads a binary on every run. Mitigated by an exact
  version pin and checksum verification. (Verifying the `SHA256SUMS.sig` GPG signature is a next
  step.)
- More moving parts than a built-in tool: hooks are needed before init, apply **and** destroy,
  because a run paused for confirmation resumes without previously installed tools.
- One version must stay consistent in several places: `TERRAFORM_VERSION` in
  `.spacelift/config.yml` is the single source, and `scripts/check-terraform-version.sh`
  (Spacelift hook + CI) fails on any drift.

**Production alternative:** bake Terraform into a custom runner image (no per-run download), or
use OpenTofu, which Spacelift supports natively and which is a drop-in replacement.

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
