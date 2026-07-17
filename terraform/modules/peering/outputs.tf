output "peering_connection_id" {
  description = "ID of the peering connection we created"
  value       = aws_vpc_peering_connection.this.id
}
