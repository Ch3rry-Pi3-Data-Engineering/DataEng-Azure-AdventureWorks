terraform {
  required_version = ">= 1.5"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }
}

provider "databricks" {
  host  = var.databricks_host
  token = var.databricks_token
}

data "databricks_current_user" "me" {}

locals {
  notebook_name   = var.notebook_name != null ? var.notebook_name : "Silver Transformations"
  notebook_path   = "/Users/${data.databricks_current_user.me.user_name}/${local.notebook_name}"
  notebook_source = var.notebook_source != null ? var.notebook_source : "${path.module}/../../notebooks/Silver Transformations.ipynb"
}

resource "databricks_notebook" "silver_transformations" {
  path      = local.notebook_path
  source    = local.notebook_source
  format    = "JUPYTER"
}
