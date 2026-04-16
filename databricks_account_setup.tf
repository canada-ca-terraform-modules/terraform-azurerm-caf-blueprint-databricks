provider "databricks" {
  alias = "azure_account"
  host = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_config.account_id
}

resource "databricks_metastore_assignment" "this" {

  metastore_id = var.databricks_config.metastore_id
  workspace_id = azapi_resource.databricks.output.properties.workspaceId

  provider = databricks.azure_account

  depends_on = [ azapi_resource.databricks ]
}

data "databricks_group" "account_admins" {

  display_name = var.databricks_config.account_admins_group_name

  provider = databricks.azure_account
}

resource "databricks_mws_permission_assignment" "account-admins-are-workspace-admins" {

  workspace_id = azapi_resource.databricks.output.properties.workspaceId
  principal_id = data.databricks_group.account_admins.id
  permissions = ["ADMIN"]

  provider = databricks.azure_account

  depends_on = [ databricks_metastore_assignment.this ]
}