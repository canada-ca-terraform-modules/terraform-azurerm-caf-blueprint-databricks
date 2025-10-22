# Reading the L1 terraform state
/*
data "terraform_remote_state" "L1" {
  backend = "azurerm"
  config  = var.L1_terraform_remote_state_config
}
*/

data "terraform_remote_state" "L1" {
  backend = "azurerm"
  config = {
    storage_account_name = var.L1_terraform_remote_state_account_name
    container_name       = var.L1_terraform_remote_state_container_name
    key                  = var.L1_terraform_remote_state_key
    resource_group_name  = var.L1_terraform_remote_state_resource_group_name
    subscription_id      = var.L1_terraform_remote_state_subscription_id
  }
}

# Mapping needed outputs from L1 statefile to locals for easy access

locals {
  resource_groups_L1       = data.terraform_remote_state.L1.outputs.resource_groups_L1
  subnets                  = data.terraform_remote_state.L1.outputs.subnets
  Project-vnet = data.terraform_remote_state.L1.outputs.Project-vnet
}
