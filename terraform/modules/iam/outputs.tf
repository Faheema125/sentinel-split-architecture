# Other modules (EKS) will need these ARNs to say "use this role"

output "eks_cluster_role_arn" {
  description = "ARN of the cluster role — passed to EKS"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn_gateway" {
  description = "ARN of gateway node role — passed to gateway node group"
  value       = aws_iam_role.eks_node_gateway.arn
}

output "eks_node_role_arn_backend" {
  description = "ARN of backend node role — passed to backend node group"
  value       = aws_iam_role.eks_node_backend.arn
}
