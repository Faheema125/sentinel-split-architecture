# Variables for the root module. These are the "settings" for our deployment.

variable "aws_region" {
  description = "Where in AWS to create everything"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "dev, staging, or prod"
  type        = string
  default     = "dev"
}
