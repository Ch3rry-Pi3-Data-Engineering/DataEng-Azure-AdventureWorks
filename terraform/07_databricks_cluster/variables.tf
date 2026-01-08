variable "databricks_host" {
  type        = string
  description = "Databricks workspace URL (https://adb-<id>.<region>.azuredatabricks.net)."
}

variable "databricks_token" {
  type        = string
  description = "Databricks personal access token (or set DATABRICKS_TOKEN)."
  sensitive   = true
  default     = null
}

variable "cluster_name" {
  type        = string
  description = "Cluster name (if null, uses cluster_name_prefix + random suffix)"
  default     = null
}

variable "cluster_name_prefix" {
  type        = string
  description = "Prefix used to build the cluster name when cluster_name is null"
  default     = "dbc-adventureworks"
}

variable "spark_version" {
  type        = string
  description = "Databricks runtime version"
  default     = "16.4.x-scala2.13"
}

variable "node_type_id" {
  type        = string
  description = "Databricks node type"
  default     = "Standard_D4pds_v6"
}

variable "autotermination_minutes" {
  type        = number
  description = "Auto-termination minutes"
  default     = 30
}

variable "runtime_engine" {
  type        = string
  description = "Runtime engine (PHOTON or STANDARD)"
  default     = "PHOTON"
}

variable "data_security_mode" {
  type        = string
  description = "Data security mode for the cluster"
  default     = "DATA_SECURITY_MODE_AUTO"
}

variable "adls_storage_account_name" {
  type        = string
  description = "Storage account name used for ADLS OAuth (dfs endpoint) and exported as STORAGE_ACCOUNT_NAME."
  default     = null
}

variable "adls_oauth_client_id" {
  type        = string
  description = "Client ID for ADLS OAuth."
  default     = null
}

variable "adls_oauth_client_secret" {
  type        = string
  description = "Client secret for ADLS OAuth."
  sensitive   = true
  default     = null
}

variable "adls_oauth_tenant_id" {
  type        = string
  description = "Tenant ID for ADLS OAuth."
  default     = null
}

variable "cluster_kind" {
  type        = string
  description = "Cluster kind (for example, CLASSIC_PREVIEW)"
  default     = "CLASSIC_PREVIEW"
}

variable "is_single_node" {
  type        = bool
  description = "Create a single-node cluster"
  default     = true
}

variable "num_workers" {
  type        = number
  description = "Number of workers when not a single-node cluster"
  default     = 2
}
