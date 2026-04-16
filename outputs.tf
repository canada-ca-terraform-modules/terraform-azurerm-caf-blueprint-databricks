output "workspace" {
  value = azapi_resource.databricks
}

output "storage" {
  value = module.databricks-storage-account
}