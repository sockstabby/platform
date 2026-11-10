# Spacelift setup (UI steps, or the GraphQL API)

Account: `sockstabby` (`https://sockstabby.app.us.spacelift.io`, US region; AWS principal 577638371743), Free plan.

Terraform is **HashiCorp Terraform 1.17.1**, run through Spacelift's **Custom** workflow tool.
Spacelift only supplies open-source Terraform (MPL, <= 1.5.7) and OpenTofu, so it will not
download BSL-licensed Terraform for us; we install it ourselves in a hook. See the README
design decision "Terraform via Spacelift's Custom workflow".

## What the repo provides (nothing to type into the UI for these)

| File | Purpose |
|---|---|
| `.spacelift/config.yml` | Runtime config for **all** stacks: `TERRAFORM_VERSION` (single source), `AWS_REGION`/`AWS_DEFAULT_REGION=us-east-2`, and hooks `before_init`, `before_apply`, `before_destroy` -> `install-terraform.sh` |
| `.spacelift/workflow.yml` | Commands Spacelift runs for each phase (init, plan, show, apply, destroy, ...) |
| `.spacelift/install-terraform.sh` | Downloads Terraform + `SHA256SUMS` from releases.hashicorp.com, verifies the checksum (fails on mismatch), installs to `/mnt/workspace/.bin` |
| `scripts/check-terraform-version.sh` | Drift check, run by the hook and by CI |

Why a hook before **apply** and **destroy** too: when a run pauses for confirmation (every prod
run, since prod autodeploy is off), Spacelift resumes it without the tools installed in earlier
phases. Without `before_apply`, prod applies would fail with `terraform: not found`.

## One-time: AWS integration

1. **Integrate Services → Cloud integrations → AWS → Add integration**
2. Name: `modern-cloud-stack`
3. Role ARN: output `spacelift_role_arn` of `bootstrap/` (`arn:aws:iam::708884111549:role/modern-cloud-stack-spacelift`)
4. Session duration: 3600 (max for public workers). Leave **Assume role on worker** off (no private worker on Free).
5. The role trusts only ExternalIds `sockstabby@*@<stack>@*` for the six stack names below, so the
   stack names must match exactly.

## The six stacks

| Stack | Project root | Autodeploy | Env |
|---|---|---|---|
| `debug-network` | `components/terraform/network` | **ON** | debug |
| `debug-github-oidc` | `components/terraform/github-oidc` | **ON** | debug |
| `debug-eks` | `components/terraform/eks` | **ON** | debug |
| `prod-network` | `components/terraform/network` | **OFF** (manual confirm) | prod |
| `prod-github-oidc` | `components/terraform/github-oidc` | **OFF** (manual confirm) | prod |
| `prod-eks` | `components/terraform/eks` | **OFF** (manual confirm) | prod |

For **each** stack (**Ship Infra → Stacks → Create stack**):

1. **Name**: exactly as in the table (the slug is used in the IAM trust policy).
2. **VCS**: GitHub, repo `sockstabby/platform`, branch `main`, **Project root** from the table.
3. **Vendor**: Terraform → **Workflow tool: Custom**. (The version selector disappears; the version
   comes from `TERRAFORM_VERSION` in `.spacelift/config.yml`.)
4. **State**: **do not** let Spacelift manage state. State lives in our S3 bucket (`backend "s3"`
   in each component), so it stays usable from the CLI.
5. **Behavior**: Autodeploy per the table.
6. **Integrations**: attach the `modern-cloud-stack` AWS integration with **read and write**.
7. **Environment** variables (per stack; `<env>` = debug|prod, `<component>` = network|github-oidc|eks):

   | Variable | Value |
   |---|---|
   | `TF_CLI_ARGS_init` | `-backend-config=key=<env>/<component>.tfstate` (bucket and region are fixed in each `backend.tf`) |
   | `TF_CLI_ARGS_plan` | `-var-file=../../../stacks/<env>/<component>.tfvars` |
   | `TF_CLI_ARGS_destroy` | `-var-file=../../../stacks/<env>/<component>.tfvars` |

   These are read by **Terraform itself**, not by Spacelift, so they work with the Custom tool
   (we control the exact commands in `workflow.yml`). Do **not** set `TF_CLI_ARGS_apply`:
   apply uses the saved plan file, which already contains the variables, and Terraform rejects
   `-var-file` together with a saved plan. Example for `debug-network`: `TF_CLI_ARGS_init=-backend-config=key=debug/network.tfstate`, `TF_CLI_ARGS_plan=-var-file=../../../stacks/debug/network.tfvars`.
8. **Hooks**: nothing to add. Open **Settings → Customizing workflow** and check that the
   `before_init`, `before_apply` and `before_destroy` hooks from `.spacelift/config.yml` show up.

## Debug bring-up order (one public worker: runs are serialized)

1. `debug-network`. First run also proves the Custom tool works: in the run log look for
   `[install-terraform] checksum OK` and `installed Terraform v1.17.1`.
2. **Verify routes before EKS** (nodes can't join or pull from GHCR without them):
   ```sh
   export AWS_PROFILE=mod-cloud-stack AWS_REGION=us-east-2
   VPC=$(aws ec2 describe-vpcs --filters Name=tag:project,Values=modern-cloud-stack Name=tag:environment,Values=debug --query 'Vpcs[0].VpcId' --output text)
   aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC --query 'RouteTables[].{rt:RouteTableId,subnets:Associations[].SubnetId,routes:Routes[].[DestinationCidrBlock,NatGatewayId,GatewayId,DestinationPrefixListId]}'
   ```
   Expect: the private route table has `0.0.0.0/0 -> nat-...` and an S3 prefix-list route (`pl-...`
   -> `vpce-...`); the public one has `0.0.0.0/0 -> igw-...`.
3. `debug-github-oidc` (quick).
4. `debug-eks` (~15 min).
5. `aws eks update-kubeconfig --region us-east-2 --name modern-cloud-stack-debug && kubectl get nodes`

Apply order: `network → github-oidc → eks`. Destroy in reverse. One public worker on Free means
runs are serialized; trigger the next stack as soon as the previous one starts applying.

## Alternative: the same setup through the API (how this repo was actually set up)

Every UI step above maps to one GraphQL mutation. Log in once (browser), then call the API with
the CLI's token:

```sh
mise exec spacectl@1.29.1 -- spacectl profile login --method browser \
  --endpoint https://sockstabby.app.us.spacelift.io sockstabby
TOKEN=$(mise exec spacectl@1.29.1 -- spacectl profile export-token)
gql() { jq -n --arg q "$1" --argjson v "${2:-null}" '{query:$q,variables:$v}' |
  curl -s https://sockstabby.app.us.spacelift.io/graphql \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @-; }
```

| UI step | Mutation (field names checked by schema introspection, 2026-11-09) |
|---|---|
| AWS integration | `awsIntegrationCreate(name, roleArn, generateCredentialsInWorker:false, durationSeconds:3600, space:"root")` |
| Create stack | `stackCreate(manageState:false, slug:"<name>", input:{name, repository:"platform", namespace:"sockstabby", branch:"main", provider:GITHUB, projectRoot, space:"root", autodeploy, vendorConfig:{terraform:{workflowTool:CUSTOM}}})` (don't pass `vcsIntegrationId` for the managed GitHub integration; the API rejects it) |
| Env vars | `stackConfigAdd(stack, config:{id:"TF_CLI_ARGS_init", value, type:ENVIRONMENT_VARIABLE, writeOnly:false})` |
| Attach integration | `awsIntegrationAttach(id, stack, read:true, write:true)`. Spacelift test-assumes the role here, so the bootstrap trust policy must already be applied |
| Trigger a run | `runTrigger(stack, commitSha, runType:PROPOSED)` (plan only) or `TRACKED` |

`awsIntegration(id){ externalIdForStack(stackId, read:true, write:true){ externalId assumeRolePolicyStatement } }`
returns the exact trust statement Spacelift expects, which is a quick way to check `bootstrap/`.
Confirming prod runs is deliberately left to a person in the UI.

## Prod bring-up order

Same as debug, but every run stops at **Unconfirmed**; review the plan and press **Confirm** in
the UI. Verify the prod routes (same command with `environment=prod`) before confirming `prod-eks`.

## Free-plan feature check (pricing page, 2026-11-09)

| Feature | Free? | Used? |
|---|---|---|
| Cloud integrations (AWS) | Yes | Yes |
| Stack dependencies ("Dependencies") | Listed as Yes | Optional; order is documented instead |
| Contexts | Not mentioned on the pricing page | Not needed: shared env lives in `.spacelift/config.yml` |
| Drift detection | **No** (Business) | No; listed as a next step |
| Policies (OPA) | **No** (Starter) | No; listed as a next step |
| Private workers | **No** | No; that's why the EKS API endpoint is public |

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `could not read custom workflow file source/.spacelift/workflow.yml` | Workflow tool set to Custom but the file is missing on the tracked branch |
| `terraform: not found` during apply | `before_apply` hook missing (check runtime config was picked up) |
| `checksum MISMATCH` | Download corrupted or tampered with; the run stops on purpose. Retry; if persistent, investigate |
| `drift-check: ... expected exactly "1.17.1"` | Someone changed one version location; update all of them together |
| `unauthorized: you need to configure trust relationship` when attaching | Trust policy principal is for the wrong Spacelift region: `spacelift.io` = 324880187172, `us.spacelift.io` = 577638371743 |
| `AccessDenied` on AssumeRole | Stack name doesn't match the trust policy's ExternalId pattern, or integration not attached |
