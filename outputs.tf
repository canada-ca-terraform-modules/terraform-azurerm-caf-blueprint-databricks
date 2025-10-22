output "workspace" {
  value = azurerm_databricks_workspace.this
}

output "storage" {
  value = module.databricks-storage-account
}