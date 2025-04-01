output "host" {
  description = "DNS hostname of the cluster configuration endpoint"
  value       = module.memory_db.cluster_endpoint_address
}

output "port" {
  description = "Port number that the cluster configuration endpoint is listening on"
  value       = module.memory_db.cluster_endpoint_port
}
