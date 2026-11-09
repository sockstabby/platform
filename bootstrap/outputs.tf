output "state_bucket" {
  description = "S3 bucket holding every component's state."
  value       = aws_s3_bucket.state.bucket
}

output "github_oidc_provider_arn" {
  description = "Account-global GitHub OIDC provider (looked up by the github-oidc component)."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "spacelift_role_arn" {
  description = "Paste into Spacelift: Integrations -> AWS -> Role ARN."
  value       = aws_iam_role.spacelift.arn
}
