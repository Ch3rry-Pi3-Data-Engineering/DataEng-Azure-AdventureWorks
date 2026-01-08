output "cluster_id" {
  value       = databricks_cluster.main.id
  description = "ID of the Databricks cluster"
}

output "cluster_name" {
  value       = databricks_cluster.main.cluster_name
  description = "Name of the Databricks cluster"
}
