# Spacelift setup (manual, in the Spacelift UI)

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
| `AccessDenied` on AssumeRole | Stack name doesn't match the trust policy's ExternalId pattern, or integration not attached |
