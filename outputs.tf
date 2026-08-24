output "workspace" {
  value = azurerm_databricks_workspace.databricks
}

output "storage" {
  value = module.databricks-storage-account
}