variable "databricks_workspace" {
  type = any
  default = {}
}

variable "databricks_config" {
  type = object({
    account_id = string
    metastore_id = string
  })
}

module "databricks" {
    source = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-blueprint-databricks?ref=mvp"

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

}