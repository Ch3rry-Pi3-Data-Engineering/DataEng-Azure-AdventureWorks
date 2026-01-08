variable "resource_group_name" {
  type        = string
  description = "Resource group name for the access connector."
}

variable "location" {
  type        = string
  description = "Azure region for the access connector. If null, uses the resource group location."
  default     = null
}

variable "storage_account_id" {
  type        = string
  description = "Resource ID of the storage account."
}

variable "access_connector_name" {
  type        = string
  description = "Access connector name override (if null, uses prefix + random suffix)."
  default     = null
}

variable "access_connector_name_prefix" {
  type        = string
  description = "Prefix for access connector name."
  default     = "dac-adventureworks"
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
