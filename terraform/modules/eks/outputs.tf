output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "URL to reach the Kubernetes API"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificate to verify the cluster's identity"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}
