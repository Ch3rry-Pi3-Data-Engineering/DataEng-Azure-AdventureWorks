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

variable "notebook_name" {
  type        = string
  description = "Notebook name in the user workspace (defaults to Silver Transformations)."
  default     = null
}

variable "notebook_source" {
  type        = string
  description = "Local path to the notebook file (defaults to notebooks/Silver Transformations.ipynb)."
  default     = null
}
