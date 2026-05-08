databricks_config = {
  account_id = "00000000-0000-0000-0000-000000000000" # can be found in the accounts.azuredatabricks.net 
  metastore_id = "00000000-0000-0000-0000-000000000000" # can be found in the accounts.azuredatabricks.net 
  account_admins_group_name = "admins-group" # the group that is granted workspace admin permissions. Can be an account-level group or an Entra group, if automatic provisioning is enabled.
  #protected_b = true
}

databricks_workspace = {
  name = "testing"
  
  # Leveraging existing subnets in the LZ vnet
  private_subnet = "PRIVATE"
  public_subnet = "PUBLIC"
  
  # Subnet for workspace private endpoint
  pe_subnet = "OZ"

  sku = "premium"
  resource_group = "Databricks"
  
  workspace_users = {
    "some.user@org.com" = { 
        display_name = "Some User"
    }
  }
  
  workspace_admins = ["some.user@org.com"] # must be in the list of workspace users

  storage = {
    subnet = "OZ" # Subnet for private endpoints

    data_share_access = [
      "some.user@org.com",
    ]
  }
}