output "result" {
  value = {
    values = {
      host = module.memory_db.cluster_endpoint_address
      port = module.memory_db.cluster_endpoint_port
    }
  }
  description = "The result of the Recipe. Must match the target resource's schema."
}
