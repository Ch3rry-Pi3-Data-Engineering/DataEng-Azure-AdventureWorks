output "access_connector_id" {
  value = azurerm_databricks_access_connector.main.id
}

output "access_connector_name" {
  value = azurerm_databricks_access_connector.main.name
}

output "access_connector_principal_id" {
  value = azurerm_databricks_access_connector.main.identity[0].principal_id
}

output "container_role_assignment_ids" {
  value = { for name, assignment in azurerm_role_assignment.container_access : name => assignment.id }
}
