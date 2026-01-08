terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "random_pet" "access" {
  length    = 2
  separator = "-"
}

locals {
  location = coalesce(var.location, data.azurerm_resource_group.main.location)

  connector_name = var.access_connector_name != null ? var.access_connector_name : "${var.access_connector_name_prefix}-${random_pet.access.id}"

  container_scopes = {
    for name in var.container_names :
    name => format("%s/blobServices/default/containers/%s", var.storage_account_id, name)
  }
}

resource "azurerm_databricks_access_connector" "main" {
  name                = local.connector_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = local.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "container_access" {
  for_each = local.container_scopes

  scope                = each.value
  role_definition_name = var.role_definition_name
  principal_id         = azurerm_databricks_access_connector.main.identity[0].principal_id

  skip_service_principal_aad_check = true
}
