variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group"
}

variable "location" {
  type        = string
  description = "Azure region for Synapse (defaults to RG location if null)"
  default     = null
}

variable "workspace_name" {
  type        = string
  description = "Synapse workspace name (if null, uses workspace_name_prefix + random suffix)"
  default     = null
}

variable "workspace_name_prefix" {
  type        = string
  description = "Prefix used to build the workspace name when workspace_name is null"
  default     = "synapse-adventureworks"
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name for Synapse (if null, uses storage_account_name_prefix + random suffix)"
  default     = null
}

variable "storage_account_name_prefix" {
  type        = string
  description = "Prefix used to build the storage account name when storage_account_name is null"
  default     = "stsynapse"
}

variable "filesystem_name" {
  type        = string
  description = "ADLS Gen2 filesystem name used by Synapse"
  default     = "synapse"
}

variable "account_tier" {
  type        = string
  description = "Storage account tier"
  default     = "Standard"
}

variable "account_replication_type" {
  type        = string
  description = "Storage account replication type"
  default     = "LRS"
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public network access for Synapse and its storage account"
  default     = true
}

variable "managed_virtual_network_enabled" {
  type        = bool
  description = "Enable a managed virtual network for Synapse"
  default     = false
}

variable "sql_admin_login" {
  type        = string
  description = "SQL admin login for Synapse workspace"
}

variable "sql_admin_password" {
  type        = string
  description = "SQL admin password for Synapse workspace"
  sensitive   = true
}

variable "aad_admin_login" {
  type        = string
  description = "Microsoft Entra ID admin login (group display name recommended)"
}

variable "aad_admin_object_id" {
  type        = string
  description = "Microsoft Entra ID object ID for the admin group or user"
}

variable "storage_role_definition_name" {
  type        = string
  description = "RBAC role assigned to the Synapse managed identity over the storage account"
  default     = "Storage Blob Data Contributor"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to Synapse resources"
  default     = {}
}
