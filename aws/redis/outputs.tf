output "result" {
  value = {
    values = {
      host = aws_memorydb_cluster.memorydb_cluster.cluster_endpoint[0].address
      port = aws_memorydb_cluster.memorydb_cluster.cluster_endpoint[0].port
    }
    secrets = {
      connectionString = format("rediss://%s:%d", aws_memorydb_cluster.memorydb_cluster.cluster_endpoint[0].address, aws_memorydb_cluster.memorydb_cluster.cluster_endpoint[0].port)
    }
  }
  sensitive = true
}
