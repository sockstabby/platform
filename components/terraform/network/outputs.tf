# For humans and verification only; other components look things up by tag.
output "vpc_id" { value = module.vpc.vpc_id }
output "azs" { value = local.azs }
output "public_subnet_ids" { value = module.vpc.public_subnets }
output "private_subnet_ids" { value = module.vpc.private_subnets }
output "private_route_table_ids" { value = module.vpc.private_route_table_ids }
output "nat_gateway_ids" { value = module.vpc.natgw_ids }
output "nat_public_ips" { value = module.vpc.nat_public_ips }
output "s3_endpoint_id" { value = aws_vpc_endpoint.s3.id }
