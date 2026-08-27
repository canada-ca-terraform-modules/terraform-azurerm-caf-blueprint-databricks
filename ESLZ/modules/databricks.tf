variable "databricks_workspace" {
  type = any
  default = {}
}

variable "databricks_config" {
  type = any
}

variable "module_version" {
  type = string
  const = true # requires terraform 1.15+ or tofu 1.12+
}

variable "force_metastore_enabled" {
  type = bool
  default = null
}

module "databricks" {
    source = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-blueprint-databricks?ref=${var.module_version}"

    databricks_config = var.databricks_config
    databricks_workspace = var.databricks_workspace

    location = var.location
    
    resource_groups = local.resource_groups_L1
    subnets = local.subnets
    vnet = local.Project-vnet

    env = var.env
    group = var.group
    project = var.project
    tags = var.tags
    force_metastore_enabled = var.force_metastore_enabled

}

output "workspace_id" {
  value = module.databricks.workspace.id
}