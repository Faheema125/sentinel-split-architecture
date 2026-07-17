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
    bucket         = "sentinel-terraform-state-rapyd"
    key            = "sentinel-split/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "sentinel-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  # Every resource gets these tags automatically. Helps with billing & finding stuff.
  default_tags {
    tags = {
      Project     = "rapyd-sentinel"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
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
  vpc_cidr             = "10.1.0.0/16"    # different range! can't overlap with gateway
  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24"]
  availability_zones   = ["us-west-2a", "us-west-2b"]
  environment          = var.environment
  enable_nat_gateway   = true
}
