variable "resource_group_name" {
  type        = string
  description = "Resource group name for lookups."
}

variable "location" {
  type        = string
  description = "Azure region for role assignment lookups. If null, uses the resource group location."
  default     = null
}

variable "storage_account_id" {
  type        = string
  description = "Resource ID of the storage account."
}

variable "application_display_name" {
  type        = string
  description = "Override for the Azure AD application display name."
  default     = null
}

variable "application_display_name_prefix" {
  type        = string
  description = "Prefix for the Azure AD application display name."
  default     = "sp-adventureworks-adls"
}

variable "role_definition_name" {
  type        = string
  description = "RBAC role to grant on each container."
  default     = "Storage Blob Data Contributor"
}

variable "container_names" {
  type        = list(string)
  description = "Containers to grant access to."
  default     = ["bronze", "silver", "gold", "parameters"]
}

variable "secret_end_date_relative" {
  type        = string
  description = "Relative expiration for the client secret (for example, 2160h = 90 days)."
  default     = "2160h"
}
