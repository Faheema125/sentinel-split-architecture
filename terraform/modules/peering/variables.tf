# Inputs for the peering module.
# We need IDs and CIDRs of both VPCs, plus their route tables to add routes to.

variable "requester_vpc_id" {
  description = "VPC ID of the gateway (the one requesting the connection)"
  type        = string
}

variable "accepter_vpc_id" {
  description = "VPC ID of the backend (the one accepting)"
  type        = string
}

variable "requester_vpc_cidr" {
  description = "CIDR of gateway VPC (10.0.0.0/16)"
  type        = string
}

variable "accepter_vpc_cidr" {
  description = "CIDR of backend VPC (10.1.0.0/16)"
  type        = string
}

variable "requester_route_table_ids" {
  description = "Gateway's private route table IDs — we add a route to these"
  type        = list(string)
}

variable "accepter_route_table_ids" {
  description = "Backend's private route table IDs — we add a route to these"
  type        = list(string)
}

variable "environment" {
  type = string
}
