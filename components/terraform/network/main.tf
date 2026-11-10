# Don't hard-code AZ names: take the first two available zones in the region.
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Community VPC module: single_nat_gateway gives exactly one NAT (in the first AZ) with both private
# route tables pointing at it. Routes are verified after apply (see docs/spacelift-setup.md) because
# private nodes cannot join the cluster or pull from GHCR without them.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = true  # LAB TRADEOFF: an outage in AZ 1 cuts egress for the whole env
  one_nat_gateway_per_az = false # production: true (NAT per AZ)

  map_public_ip_on_launch = false # nodes never get public IPs
  enable_dns_hostnames    = true
  enable_dns_support      = true

  # `tier` is what other components use to find subnets (data sources, no remote state).
  public_subnet_tags = {
    tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Free gateway endpoint: S3 traffic from private subnets skips the NAT data-processing charge.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "${local.name}-s3"
  }
}
