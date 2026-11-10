# Teardown

Everything here bills by the hour (~$0.24/h per environment; see the README cost table), so tear
down in this order. Run from a shell with the admin profile:

```sh
export AWS_PROFILE=mod-cloud-stack AWS_REGION=us-east-2
```

## 1. Uninstall Helm releases (both clusters)

Anything a release created outside Terraform (e.g. a `LoadBalancer` Service creates an ELB) would
otherwise be orphaned or block the VPC deletion. This project only uses ClusterIP, but do it anyway.

```sh
for env in debug prod; do
  ctx=modern-cloud-stack-$env
  aws eks update-kubeconfig --name $ctx --alias $ctx >/dev/null
  helm --kube-context $ctx -n apps list
  helm --kube-context $ctx -n apps uninstall app-template --wait
  kubectl --context $ctx get svc -A | grep LoadBalancer || echo "$env: no LoadBalancer services"
done
```

## 2. Destroy the stacks through Spacelift: `eks → github-oidc → network`, per environment

In Spacelift, open the stack → **Tasks** → run `terraform destroy`, or trigger a destroy run
(the API equivalent is `runTrigger(stack, runType: DESTROY)`; see
[spacelift-setup.md](spacelift-setup.md)). Prod stacks stop at **Unconfirmed**: review the
destroy plan and confirm.

| Order | debug | prod |
|---|---|---|
| 1 | `debug-eks` (~10 min) | `prod-eks` (~10 min) |
| 2 | `debug-github-oidc` | `prod-github-oidc` |
| 3 | `debug-network` (NAT + EIP go here) | `prod-network` |

Destroy `eks` before `network` (the cluster's ENIs and security groups sit in the VPC) and before
`github-oidc` (the eks component looks up the deploy role). Check each destroy plan deletes the
expected count and nothing else (eks 36, github-oidc 2, network 20).

After each `network` destroy, confirm the NAT gateway and its Elastic IP are gone; both bill while
orphaned:

```sh
aws ec2 describe-nat-gateways --filter Name=tag:project,Values=modern-cloud-stack \
  --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]' --output text
aws ec2 describe-addresses --filters Name=tag:project,Values=modern-cloud-stack \
  --query 'Addresses[].[AllocationId,PublicIp]' --output text
```

## 3. (Optional) Destroy `bootstrap/` locally

Only if nothing else will use the state bucket, the GitHub OIDC provider or the Spacelift role.
Two complications: bootstrap's own state lives in the bucket it creates, and the bucket is
versioned with `force_destroy = false`, so it must be emptied of **every version and delete
marker** before Terraform can delete it.

1. **Move bootstrap's state back to local.** Comment out the `backend "s3"` block in
   `bootstrap/` (keep a copy), then:
   ```sh
   cd bootstrap
   mise exec -- terraform init -migrate-state   # answer "yes" to copy the S3 state to local
   mise exec -- terraform plan                  # expect: No changes
   ```
2. **Empty the bucket** (all versions and delete markers; repeats until nothing is left):
   ```sh
   B=modern-cloud-stack-tfstate-708884111549
   while :; do
     aws s3api list-object-versions --bucket "$B" --max-keys 1000 --output json \
       --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}, Quiet: `true`}' > /tmp/del.json
     [ "$(jq '.Objects | length' /tmp/del.json)" -eq 0 ] && break
     aws s3api delete-objects --bucket "$B" --delete file:///tmp/del.json >/dev/null
   done
   ```
3. **Destroy:** `mise exec -- terraform destroy` (expect the bucket and its settings, the OIDC
   provider, the Spacelift role and its policy attachment).

## 4. Credentials and accounts

- **Deactivate the IAM user's access key** used for this project (`modern-cloud-stack`):
  `aws iam list-access-keys --user-name modern-cloud-stack`, then
  `aws iam update-access-key --user-name modern-cloud-stack --access-key-id <id> --status Inactive`
  (delete it once you're sure). Do this last; every command above needs it.
- **Spacelift:** delete the six stacks and the `modern-cloud-stack` AWS integration (with the role
  gone, the integration is useless anyway).
- **GitHub (optional):** delete the `ghcr.io/sockstabby/app-template` package; remove the
  `debug`/`production` Environments if the repo is kept as a template only.
- Remove the kube contexts: `kubectl config delete-context modern-cloud-stack-debug` (and `-prod`).

## 5. Final check

Tagged resources (the provider's `default_tags` put `project=modern-cloud-stack` on everything
Terraform created). Check us-east-2 and us-east-1 (IAM is global and some global resources
surface in us-east-1):

```sh
for r in us-east-2 us-east-1; do
  echo "== $r"
  aws resourcegroupstaggingapi get-resources --region $r \
    --tag-filters Key=project,Values=modern-cloud-stack \
    --query 'ResourceTagMappingList[].ResourceARN' --output text
done
```

The tagging API can list recently deleted resources for a while and doesn't cover everything, so
also check directly for the things that keep billing:

```sh
aws eks list-clusters
aws ec2 describe-nat-gateways --query 'NatGateways[?State!=`deleted`].NatGatewayId'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId'
aws ec2 describe-vpcs --filters Name=tag:project,Values=modern-cloud-stack --query 'Vpcs[].VpcId'
```

All should be empty (or show only resources unrelated to this project).
