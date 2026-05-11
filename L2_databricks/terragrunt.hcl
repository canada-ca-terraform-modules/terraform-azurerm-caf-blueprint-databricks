locals {
  config = read_terragrunt_config("../config.hcl").locals
  backend_config = read_terragrunt_config("../remote_state.hcl").locals
  // Define the directory containing your tfvars files

  tfvars_directory = "${get_terragrunt_dir()}/config"

  tfvar_files = [ 
    for file in fileset(local.tfvars_directory, "*.tfvars") :
      "${local.tfvars_directory}/${file}" 
  ]

  databricks_config = jsondecode(read_tfvars_file("${local.tfvars_directory}/databricks.tfvars"))

  # When set to false, the public access setting will be disabled post-deployment, and reenabled pre-destroy to ensure connectivity while the private endpoint is being configured/removed.
  public_network_access = lookup(local.databricks_config.databricks_workspace, "public_network_access", true) 

  release = "v0.1.0" # Update with the desired release tag or branch
}

# stage/mysql/root.hcl
include "remote" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependencies {
  paths = ["../L1_blueprint_base"]
}

terraform {
  source = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-blueprint-databricks?ref=${local.release}//ESLZ/modules"

  before_hook "check_and_update_public_access" {
    commands = ["destroy"]
    execute  = ["./check-and-update-public-access.sh"]
    if      = !local.public_network_access
  }

   after_hook "check_and_update_public_access" {
    commands = ["apply"]
    execute  = ["./check-and-update-public-access.sh"]
    if      = !local.public_network_access
  }

  extra_arguments "apply" {
    commands = [
      "apply"
    ]
    env_vars = {
      ARM_SUBSCRIPTION_ID = local.config.subscription_id
    }
    required_var_files = get_env("TERRAGRUNT_PIPELINE_RUN", "false") == "false" ? local.tfvar_files : []
  }
  extra_arguments "tfvars_files" {
    commands = [
      "init",
      "destroy",
      "refresh",
      "import",
      "plan",
      "refresh"
    ]
    env_vars = {
      ARM_SUBSCRIPTION_ID = local.config.subscription_id
    }
    required_var_files = local.tfvar_files
  }


}

inputs = {
  
  L1_terraform_remote_state_account_name        = local.backend_config.storage_account_name
  L1_terraform_remote_state_container_name      = local.backend_config.container_name
  L1_terraform_remote_state_key                 = local.backend_config.L1_remote_state_key
  L1_terraform_remote_state_resource_group_name = local.backend_config.resource_group_name
  L1_terraform_remote_state_subscription_id     = local.config.subscription_id

  tags                                          = include.remote.inputs.tags
}