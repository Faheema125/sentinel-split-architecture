# These are what the module "returns" after it creates everything.
# Other modules can reference these, like module.vpc_gateway.vpc_id

output "vpc_id" {
  description = "The VPC's unique ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The VPC's IP range"
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets we created"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets we created"
  value       = aws_subnet.public[*].id
}

output "private_route_table_ids" {
  description = "Route table IDs (needed by the peering module to add routes)"
  value       = [aws_route_table.private.id]
}
