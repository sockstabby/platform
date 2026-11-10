# OIDC verification (debug), 2026-11-09

Before any deploy relied on the GitHub → AWS → EKS chain, a temporary `workflow_dispatch`
workflow in `app-template` (`oidc-whoami.yml`, since deleted) ran once on `main` with
`environment: debug`. It printed only the token's claims (never the token), then assumed the
role and checked Kubernetes permissions. Run: https://github.com/sockstabby/app-template/actions/runs/42744110827

## Claims

```json
{
  "sub": "repo:sockstabby@17520257/app-template@1451897217:environment:debug",
  "aud": "sts.amazonaws.com",
  "environment": "debug",
  "repository": "sockstabby/app-template",
  "repository_id": "1451897217",
  "repository_owner_id": "17520257",
  "job_workflow_ref": "sockstabby/app-template/.github/workflows/oidc-whoami.yml@refs/heads/main",
  "ref": "refs/heads/main"
}
```

The repo uses GitHub's immutable subject format (owner and repo IDs embedded), which GitHub
documents for repositories created after 2026-07-15 but only with a `ref:` example. This run is
the evidence that the environment form is `repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:ENV`.
The deploy role's trust (`StringLike`) is `repo:sockstabby@17520257/*:environment:debug`, so any
repo created from the template can deploy to debug without IAM changes; the `debug` GitHub
Environment restricts deployments to `main` within each repo.

## AWS

`sts get-caller-identity` → `arn:aws:sts::708884111549:assumed-role/modern-cloud-stack-debug-deploy/oidc-whoami-42744110827`;
`eks describe-cluster` → `modern-cloud-stack-debug`, 1.37, ACTIVE.

## Kubernetes (EKS access entry: AmazonEKSEditPolicy scoped to `apps`)

```
yes  create  deployments  -n apps         (expected yes)
yes  create  secrets      -n apps         (expected yes)
no   create  deployments  -n default      (expected no)
no   get     secrets      -n kube-system  (expected no)
no   create  namespaces   -n default      (expected no)
```
