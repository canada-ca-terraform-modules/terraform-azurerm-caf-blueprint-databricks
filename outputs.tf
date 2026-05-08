output "workspace" {
  value = azapi_resource.databricks.output
}

output "storage" {
  value = module.databricks-storage-account
}