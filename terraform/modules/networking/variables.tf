# These are the inputs this module needs. When we call this module
# from main.tf, we pass values for each of these.

variable "vpc_name" {
  description = "Name prefix for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "IP range for the VPC, like 10.0.0.0/16"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "IP ranges for private subnets (list because we make 2)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "IP ranges for public subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Which data centers to use, like us-west-2a and us-west-2b"
  type        = list(string)
}

variable "environment" {
  description = "dev, staging, or prod"
  type        = string
}

variable "enable_nat_gateway" {
  description = "Set to false if you want to save money (but private subnets lose internet)"
  type        = bool
  default     = true
}
