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
}