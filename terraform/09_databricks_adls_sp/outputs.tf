output "oauth_client_id" {
  value = azuread_application.main.client_id
}

output "oauth_client_secret" {
  value     = azuread_application_password.main.value
  sensitive = true
}

output "oauth_tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "service_principal_object_id" {
  value = azuread_service_principal.main.object_id
}

output "container_role_assignment_ids" {
  value = { for name, assignment in azurerm_role_assignment.container_access : name => assignment.id }
}
