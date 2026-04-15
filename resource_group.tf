locals {
  resource_groups = merge(var.resource_groups, { "${var.databricks_workspace.resource_group}" = module.databricks-rg })
}

module "databricks-rg" {
  source = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-resource_groups.git?ref=v2.0.1"

  userDefinedString = var.databricks_workspace.resource_group
  env = var.env
  location = var.location
  group = var.group
  project = var.project
  resource_group = {}
  tags = var.tags
}