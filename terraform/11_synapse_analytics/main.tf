terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
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

data "azurerm_client_config" "current" {}

data "http" "terraform_runner_ip" {
  url = "https://api.ipify.org?format=text"
}

resource "random_pet" "workspace" {
  length    = 2
  separator = "-"
}

resource "random_pet" "storage" {
  length    = 2
  separator = ""
}

locals {
  workspace_name       = var.workspace_name != null ? var.workspace_name : "${var.workspace_name_prefix}-${random_pet.workspace.id}"
  managed_rg_name      = var.managed_resource_group_name != null ? var.managed_resource_group_name : "${var.managed_resource_group_name_prefix}-${random_pet.workspace.id}"
  storage_account_name = var.storage_account_name != null ? var.storage_account_name : substr("${var.storage_account_name_prefix}${random_pet.storage.id}", 0, 24)
  terraform_runner_ip  = trimspace(data.http.terraform_runner_ip.response_body)
}

resource "azurerm_storage_account" "synapse" {
  name                          = local.storage_account_name
  resource_group_name           = data.azurerm_resource_group.main.name
  location                      = coalesce(var.location, data.azurerm_resource_group.main.location)
  account_tier                  = var.account_tier
  account_replication_type      = var.account_replication_type
  account_kind                  = "StorageV2"
  is_hns_enabled                = true
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = var.public_network_access_enabled

  network_rules {
    default_action = "Allow"
  }

  tags = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  name               = var.filesystem_name
  storage_account_id = azurerm_storage_account.synapse.id
}

resource "azurerm_synapse_workspace" "main" {
  name                                 = local.workspace_name
  resource_group_name                  = data.azurerm_resource_group.main.name
  location                             = coalesce(var.location, data.azurerm_resource_group.main.location)
  managed_resource_group_name          = local.managed_rg_name
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse.id
  sql_administrator_login              = var.sql_admin_login
  sql_administrator_login_password     = var.sql_admin_password
  managed_virtual_network_enabled      = var.managed_virtual_network_enabled
  public_network_access_enabled        = var.public_network_access_enabled

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_synapse_firewall_rule" "allow_terraform_runner" {
  name                 = "AllowTerraformRunnerIP"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  start_ip_address     = local.terraform_runner_ip
  end_ip_address       = local.terraform_runner_ip
}

resource "azurerm_synapse_workspace_sql_aad_admin" "admin" {
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  login                = var.aad_admin_login
  object_id            = var.aad_admin_object_id
  tenant_id            = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_synapse_role_assignment" "synapse_workspace_admin" {
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  role_name            = "Synapse Administrator"
  principal_id         = var.aad_admin_object_id

  depends_on = [azurerm_synapse_firewall_rule.allow_terraform_runner]
}

resource "azurerm_role_assignment" "synapse_workspace_owner" {
  scope                = azurerm_synapse_workspace.main.id
  role_definition_name = "Owner"
  principal_id         = var.aad_admin_object_id
}

resource "azurerm_role_assignment" "synapse_storage_access" {
  scope                = azurerm_storage_account.synapse.id
  role_definition_name = var.storage_role_definition_name
  principal_id         = azurerm_synapse_workspace.main.identity[0].principal_id

  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "synapse_shared_storage_access" {
  count = var.shared_storage_account_id != null ? 1 : 0

  scope                = var.shared_storage_account_id
  role_definition_name = var.storage_role_definition_name
  principal_id         = azurerm_synapse_workspace.main.identity[0].principal_id

  skip_service_principal_aad_check = true
}
