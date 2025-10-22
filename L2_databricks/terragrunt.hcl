locals {
  config = read_terragrunt_config("../config.hcl").locals
  backend_config = read_terragrunt_config("../remote_state.hcl").locals
  // Define the directory containing your tfvars files
  tfvars_dir = "./config"
  
  // Load all tfvars files in the specified directory
  all_tfvars = fileset(local.tfvars_dir, "*.tfvars")
  tfvar_args = [for f in local.all_tfvars : "--var-file=${local.tfvars_dir}/${f}"]

  all_json_tfvars = fileset(local.tfvars_dir, "*.tfvars.json")
  tfvars_json_args = [for x in local.all_json_tfvars : "--var-file=${local.tfvars_dir}/${x}"]

  merge_tfvars = concat(local.tfvar_args, local.tfvars_json_args)
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
  source = "./modules"

  extra_arguments "apply" {
    commands = [
      "apply"
    ]
    env_vars = {
      ARM_SUBSCRIPTION_ID = local.config.subscription_id
    }
    arguments = try(get_env("TERRAGRUNT_PIPELINE_RUN"), "false") == "false" ? local.merge_tfvars : [] # Adding the dynamically generated tfvar files
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
    arguments = local.merge_tfvars # Adding the dynamically generated tfvar files
  }
}

inputs = {
  # root.hcl include inputs are already part of inputs. Only need to add non included inputs
  L1_terraform_remote_state_account_name        = local.backend_config.storage_account_name
  L1_terraform_remote_state_container_name      = local.backend_config.container_name
  L1_terraform_remote_state_key                 = local.backend_config.L1_remote_state_key
  L1_terraform_remote_state_resource_group_name = local.backend_config.resource_group_name
  L1_terraform_remote_state_devops_key          = "L1_blueprint_devops/terraform.tfstate" 
  L1_terraform_remote_state_subscription_id     = local.config.subscription_id
  domain                                        = local.config.domain
  tags                                          = include.remote.inputs.tags
  databricks_config                             = local.config.databricks
}