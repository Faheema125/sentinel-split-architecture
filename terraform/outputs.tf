# What terraform prints after it finishes building.
# Also used by other automation to grab IDs.

output "gateway_vpc_id" {
  value = module.vpc_gateway.vpc_id
}

output "backend_vpc_id" {
  value = module.vpc_backend.vpc_id
}
