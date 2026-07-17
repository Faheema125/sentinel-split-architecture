variable "cluster_name" {
  description = "Name of the cluster (eks-gateway or eks-backend)"
  type        = string
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the cluster"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for the worker nodes"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets to place the cluster and nodes in"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC where the cluster lives"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g., 1.29)"
  type        = string
  default     = "1.29"
}

variable "environment" {
  type = string
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "allowed_cidr_blocks" {
  description = "CIDRs allowed to reach this cluster (the other VPC's range)"
  type        = list(string)
  default     = []
}
