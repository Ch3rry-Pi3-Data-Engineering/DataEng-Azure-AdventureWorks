output "workspace_id" {
  value = azurerm_synapse_workspace.main.id
}

output "workspace_name" {
  value = azurerm_synapse_workspace.main.name
}

output "sql_endpoint" {
  value = try(azurerm_synapse_workspace.main.connectivity_endpoints["sql"], null)
}

output "dev_endpoint" {
  value = try(azurerm_synapse_workspace.main.connectivity_endpoints["dev"], null)
}

output "storage_account_name" {
  value = azurerm_storage_account.synapse.name
}

output "filesystem_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.synapse.name
}
