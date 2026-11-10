data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Created once per account by bootstrap/. Never create it here (it is account-global).
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  name         = "${var.project}-${var.environment}"
  cluster_name = local.name # must match the eks component
  cluster_arn  = "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}"
  # Any repo of this owner (so repos created from the template work), but only jobs running in the
  # given GitHub Environment. `*` cannot cross into the environment segment: ':' is not allowed in
  # GitHub owner/repo names.
  sub_pattern = "repo:${var.github_owner}@${var.github_owner_id}/*:environment:${var.github_environment}"
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.sub_pattern]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "${local.name}-deploy"
  description          = "GitHub Actions deploy role for ${var.environment} (OIDC, environment-scoped)"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

# Only what `aws eks update-kubeconfig` needs. What the role may do inside the cluster is decided by
# its EKS access entry (eks component): AmazonEKSEditPolicy scoped to the apps namespace.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "DescribeOwnCluster"
    actions   = ["eks:DescribeCluster"]
    resources = [local.cluster_arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "describe-cluster"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
