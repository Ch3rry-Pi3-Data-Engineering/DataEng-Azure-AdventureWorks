terraform {
  required_version = ">= 1.5"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "databricks" {
  host  = var.databricks_host
  token = var.databricks_token
}

resource "random_pet" "cluster" {
  length    = 2
  separator = "-"
}

locals {
  cluster_name = var.cluster_name != null ? var.cluster_name : "${var.cluster_name_prefix}-${random_pet.cluster.id}"
  num_workers  = var.is_single_node ? 0 : var.num_workers

  single_node_conf = {
    "spark.databricks.cluster.profile" = "singleNode"
    "spark.master"                     = "local[*]"
  }
  single_node_tags = {
    "ResourceClass" = "SingleNode"
  }

  adls_oauth_conf = (
    var.adls_storage_account_name != null
    && var.adls_oauth_client_id != null
    && var.adls_oauth_client_secret != null
    && var.adls_oauth_tenant_id != null
  ) ? {
    "fs.azure.account.auth.type.${var.adls_storage_account_name}.dfs.core.windows.net" = "OAuth"
    "fs.azure.account.oauth.provider.type.${var.adls_storage_account_name}.dfs.core.windows.net" = "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider"
    "fs.azure.account.oauth2.client.id.${var.adls_storage_account_name}.dfs.core.windows.net" = var.adls_oauth_client_id
    "fs.azure.account.oauth2.client.secret.${var.adls_storage_account_name}.dfs.core.windows.net" = var.adls_oauth_client_secret
    "fs.azure.account.oauth2.client.endpoint.${var.adls_storage_account_name}.dfs.core.windows.net" = "https://login.microsoftonline.com/${var.adls_oauth_tenant_id}/oauth2/token"
  } : {}

  spark_conf = merge(
    var.is_single_node ? local.single_node_conf : {},
    local.adls_oauth_conf
  )

  spark_env_vars = var.adls_storage_account_name != null ? {
    "STORAGE_ACCOUNT_NAME" = var.adls_storage_account_name
  } : {}
}

resource "databricks_cluster" "main" {
  cluster_name            = local.cluster_name
  spark_version           = var.spark_version
  node_type_id            = var.node_type_id
  autotermination_minutes = var.autotermination_minutes
  data_security_mode      = var.data_security_mode
  kind                    = var.cluster_kind
  runtime_engine          = var.runtime_engine
  num_workers             = local.num_workers

  spark_conf     = local.spark_conf
  spark_env_vars = local.spark_env_vars
  custom_tags    = var.is_single_node ? local.single_node_tags : {}
}
