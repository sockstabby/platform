locals {
  name = "${var.project}-${var.environment}"
}

# ---- Look up the network by tags (no terraform_remote_state) ----
data "aws_vpc" "this" {
  tags = {
    project     = var.project
    environment = var.environment
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  tags = {
    tier = "private"
  }
}

# Created by the github-oidc component (apply order: network -> github-oidc -> eks).
data "aws_iam_role" "deploy" {
  name = "${local.name}-deploy"
}

# Created by bootstrap/.
data "aws_iam_role" "spacelift" {
  name = "${var.project}-spacelift"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = data.aws_vpc.this.id
  subnet_ids = data.aws_subnets.private.ids # control plane ENIs + nodes: private subnets only

  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # Teardown hygiene (lab): a module-created KMS key can only be *scheduled* for deletion (7-30 days,
  # $1/month meanwhile) and a CloudWatch log group would be orphaned. Production: enable secrets
  # encryption with a managed key and control-plane audit logs.
  create_kms_key              = false
  encryption_config           = null
  enabled_log_types           = []
  create_cloudwatch_log_group = false

  # Not using enable_cluster_creator_admin_permissions: it keys off whoever runs the plan, so a local
  # plan (as the admin user) and a Spacelift plan (as the Spacelift role) would differ, and a local
  # run would try to create a duplicate entry for the admin user. Name both principals explicitly.
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    spacelift = {
      # Spacelift's role applies this stack and creates the apps namespace via the kubernetes provider.
      principal_arn = data.aws_iam_role.spacelift.arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    admin = {
      principal_arn = var.admin_principal_arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    github_deploy = {
      principal_arn = data.aws_iam_role.deploy.arn
      policy_associations = {
        edit = {
          # Minimum that lets Helm manage Deployments/Services/ServiceAccounts/PDBs and its release
          # Secrets, confined to one namespace. Cluster-admin would let a compromised workflow touch
          # anything in the cluster.
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = [var.app_namespace]
          }
        }
      }
    }
  }

  addons = {
    vpc-cni    = { before_compute = true }
    kube-proxy = {}
    coredns    = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"
      subnet_ids     = data.aws_subnets.private.ids

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # The module uses a custom launch template by default, so `disk_size` would be ignored.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size_gb
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }
}

resource "kubernetes_namespace_v1" "apps" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # Access entries (incl. the creator's admin) must exist before the provider can call the API.
  depends_on = [module.eks]
}
