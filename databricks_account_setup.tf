provider "databricks" {
  alias = "azure_account"
  host = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_config.account_id
}

data "databricks_current_user" "me" {
  provider = databricks.azure_account
}

data "databricks_group" "account_admins" {

  display_name = var.databricks_config.account_admins_group_name

  provider = databricks.azure_account
}

resource "databricks_metastore_assignment" "this" {

  metastore_id = var.databricks_config.metastore_id
  workspace_id = azurerm_databricks_workspace.this.workspace_id

  provider = databricks.azure_account

  depends_on = [ azurerm_databricks_workspace.this, module.databricks-pe ]
}

resource "databricks_mws_permission_assignment" "account-admins-are-workspace-admins" {

  workspace_id = azurerm_databricks_workspace.this.workspace_id
  principal_id = data.databricks_group.account_admins.id
  permissions = ["ADMIN"]

  provider = databricks.azure_account
  depends_on = [ databricks_metastore_assignment.this ]
}

resource "databricks_mws_permission_assignment" "current-user-is-workspace-admins" {

  workspace_id = azurerm_databricks_workspace.this.workspace_id
  principal_id = databricks_current_user.me.id
  permissions = ["ADMIN"]

  provider = databricks.azure_account
  depends_on = [ databricks_metastore_assignment.this ]
}