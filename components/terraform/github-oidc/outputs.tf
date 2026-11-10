output "deploy_role_arn" {
  description = "Store as GitHub Environment variable AWS_ROLE_ARN on the matching environment."
  value       = aws_iam_role.deploy.arn
}

output "trusted_sub_pattern" {
  value = local.sub_pattern
}
