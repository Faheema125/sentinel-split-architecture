# What terraform prints after it finishes building.
# Also used by other automation to grab IDs.

output "gateway_vpc_id" {
  value = module.vpc_gateway.vpc_id
}

output "backend_vpc_id" {
  value = module.vpc_backend.vpc_id
}

output "peering_connection_id" {
  value = module.vpc_peering.peering_connection_id
}

output "eks_gateway_cluster_name" {
  value = module.eks_gateway.cluster_name
}

output "eks_backend_cluster_name" {
  value = module.eks_backend.cluster_name
}

output "eks_gateway_endpoint" {
  value = module.eks_gateway.cluster_endpoint
}

output "eks_backend_endpoint" {
  value = module.eks_backend.cluster_endpoint
}
