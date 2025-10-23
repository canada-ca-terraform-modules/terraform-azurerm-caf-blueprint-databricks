provider "databricks" {
  alias = "azure_account"
  host = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_config.account_id
}

resource "databricks_metastore_assignment" "this" {

  metastore_id = var.databricks_config.metastore_id
  workspace_id = azurerm_databricks_workspace.this.workspace_id

  provider = databricks.azure_account

  depends_on = [ azurerm_databricks_workspace.this ]
}