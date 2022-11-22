
output "public_subnets" {
  description = "Public Subnets for VPC "
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private Subnets for VPC "
  value       = module.vpc.private_subnets
}

