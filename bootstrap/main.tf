data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  state_bucket = "${var.project}-tfstate-${local.account_id}" # account ID keeps the global name unique
  # Built from the name (not aws_s3_bucket.state.arn) so the bucket policy document is known at
  # plan time; otherwise any pending bucket change (even a tag) makes the policy "known after apply".
  state_bucket_arn = "arn:aws:s3:::${local.state_bucket}"
}

# -----------------------------------------------------------------------------
# State bucket (one bucket; keys are <env>/<component>.tfstate)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
  # Deliberately false: teardown must empty the versioned bucket on purpose (see docs/teardown.md).
  # prevent_destroy is not used because it would also block an intentional teardown.
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced" # ACLs disabled
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3: free. SSE-KMS adds per-request cost with no benefit for a lab.
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      local.state_bucket_arn,
      "${local.state_bucket_arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# -----------------------------------------------------------------------------
# GitHub Actions OIDC provider: account-global, exactly one per account.
# Per-env components look it up (data source); they must never create it.
# thumbprint_list is omitted: optional since AWS provider 5.81.0, and IAM verifies
# GitHub's JWKS endpoint against its trusted root CA library (AWS IAM docs).
# -----------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# -----------------------------------------------------------------------------
# Role Spacelift assumes for the six stacks (Spacelift "AWS integration").
# ExternalId format per Spacelift docs: <account>@<integration-id>@<stack-slug>@<read|write>
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "spacelift_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.spacelift_aws_principal}:root"]
    }
    condition {
      test     = "StringLike"
      variable = "sts:ExternalId"
      values   = [for s in var.spacelift_stacks : "${var.spacelift_account_name}@*@${s}@*"]
    }
  }
}

resource "aws_iam_role" "spacelift" {
  name                 = "${var.project}-spacelift"
  description          = "Assumed by Spacelift (${var.spacelift_account_name}) stacks to manage ${var.project} infrastructure"
  assume_role_policy   = data.aws_iam_policy_document.spacelift_trust.json
  max_session_duration = 3600 # Spacelift-side assumption is capped at 1h (public worker)
}

# LAB TRADEOFF: the stacks create IAM roles (EKS cluster/node roles, GitHub deploy roles), so a
# truly least-privilege policy needs a permissions boundary on every role it creates. Production:
# scoped policy + permissions boundary + separate plan (read) and apply (write) roles.
resource "aws_iam_role_policy_attachment" "spacelift_admin" {
  role       = aws_iam_role.spacelift.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
