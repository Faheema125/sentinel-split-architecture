# Root config — this is the entry point. Terraform reads this first.
# It tells terraform what provider to use, where to store state,
# and then calls modules to build stuff.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Where terraform remembers what it created.
  # Without this, it would forget and try to create duplicates.
  backend "s3" {
    bucket  = "sentinel-terraform-state-rapyd"
    key     = "sentinel-split/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
    # DynamoDB locking skipped — no dynamodb:CreateTable permission in this account.
    # In production, you'd add a DynamoDB table to prevent concurrent state changes.
  }
}

provider "aws" {
  region = var.aws_region
}

# ---- Build the Gateway VPC ----
# This is the public-facing VPC. The proxy/load balancer lives here.
module "vpc_gateway" {
  source = "./modules/networking"

  vpc_name             = "vpc-gateway"
  vpc_cidr             = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  availability_zones   = ["us-west-2a", "us-west-2b"]
  environment          = var.environment
  enable_nat_gateway   = true
}

# ---- Build the Backend VPC ----
# This is the private VPC. The internal app lives here. No public access.
module "vpc_backend" {
  source = "./modules/networking"

  vpc_name             = "vpc-backend"
  vpc_cidr             = "10.1.0.0/16"
  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24"]
  availability_zones   = ["us-west-2a", "us-west-2b"]
  environment          = var.environment
  enable_nat_gateway   = true
}

# ---- IAM roles ----
# EKS needs roles with permissions to manage clusters and nodes.
module "iam" {
  source      = "./modules/iam"
  environment = var.environment
}

# ---- Connect the two VPCs with a private tunnel ----
# Without this, gateway and backend can't talk at all.
module "vpc_peering" {
  source = "./modules/peering"

  requester_vpc_id          = module.vpc_gateway.vpc_id
  accepter_vpc_id           = module.vpc_backend.vpc_id
  requester_vpc_cidr        = "10.0.0.0/16"
  accepter_vpc_cidr         = "10.1.0.0/16"
  requester_route_table_ids = module.vpc_gateway.private_route_table_ids
  accepter_route_table_ids  = module.vpc_backend.private_route_table_ids
  environment               = var.environment
}

# ---- EKS Gateway Cluster ----
# Runs the NGINX proxy. Public load balancer points here.
module "eks_gateway" {
  source = "./modules/eks"

  cluster_name        = "eks-gateway"
  cluster_role_arn    = module.iam.eks_cluster_role_arn
  node_role_arn       = module.iam.eks_node_role_arn_gateway
  subnet_ids          = module.vpc_gateway.private_subnet_ids
  vpc_id              = module.vpc_gateway.vpc_id
  kubernetes_version  = "1.31"
  environment         = var.environment
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3

  # allow traffic from backend VPC (for responses)
  allowed_cidr_blocks = ["10.1.0.0/16"]
}

# ---- EKS Backend Cluster ----
# Runs the "Hello from backend" app. NOT public. Only gateway can reach it.
module "eks_backend" {
  source = "./modules/eks"

  cluster_name        = "eks-backend"
  cluster_role_arn    = module.iam.eks_cluster_role_arn
  node_role_arn       = module.iam.eks_node_role_arn_backend
  subnet_ids          = module.vpc_backend.private_subnet_ids
  vpc_id              = module.vpc_backend.vpc_id
  kubernetes_version  = "1.31"
  environment         = var.environment
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3

  # ONLY allow traffic from gateway VPC — this is the key security control
  allowed_cidr_blocks = ["10.0.0.0/16"]
}
