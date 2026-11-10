provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project      = var.project
      environment  = var.environment
      "managed-by" = "terraform"
    }
  }
}

# Authenticates with a short-lived token from the AWS API (no aws CLI needed in the runner).
# NOTE: configuring a provider from a cluster created in the same configuration works for create and
# destroy, but can fail if the cluster must be *replaced*. Accepted for one namespace; see README.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}
