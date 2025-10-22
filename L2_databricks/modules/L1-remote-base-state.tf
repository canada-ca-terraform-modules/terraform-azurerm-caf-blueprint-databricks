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
  Project-law              = data.terraform_remote_state.L1.outputs.Project-law
  Project_law-sa           = data.terraform_remote_state.L1.outputs.Project_law-sa
  Project-kv               = data.terraform_remote_state.L1.outputs.Project-kv
  Project-nsg              = data.terraform_remote_state.L1.outputs.Project-nsg
  Project-rsv              = try(data.terraform_remote_state.L1.outputs.Project-rsv, null)
  Project_backup_policy_vm = try(data.terraform_remote_state.L1.outputs.Project_backup_policy_vm, null)
  Project-vnet = data.terraform_remote_state.L1.outputs.Project-vnet
  Project-dns-zone         = data.terraform_remote_state.L1.outputs.private_dns_zone_ids
  zones                    = data.terraform_remote_state.L1.outputs.zones
}
