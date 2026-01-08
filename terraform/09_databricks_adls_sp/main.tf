terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50"
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

provider "azuread" {}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azuread_client_config" "current" {}

resource "random_pet" "sp" {
  length    = 2
  separator = "-"
}

locals {
  location = coalesce(var.location, data.azurerm_resource_group.main.location)

  application_name = var.application_display_name != null ? var.application_display_name : "${var.application_display_name_prefix}-${random_pet.sp.id}"

  container_scopes = {
    for name in var.container_names :
    name => format("%s/blobServices/default/containers/%s", var.storage_account_id, name)
  }
}

resource "azuread_application" "main" {
  display_name     = local.application_name
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal" "main" {
  client_id = azuread_application.main.client_id
}

resource "azuread_application_password" "main" {
  application_object_id = azuread_application.main.id
  display_name          = "terraform"
  end_date_relative     = var.secret_end_date_relative
}

resource "azurerm_role_assignment" "container_access" {
  for_each = local.container_scopes

  scope                = each.value
  role_definition_name = var.role_definition_name
  principal_id         = azuread_service_principal.main.object_id

  skip_service_principal_aad_check = true
}
