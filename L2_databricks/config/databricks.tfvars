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
        workspace_access = true
    }
  }
  
  workspace_admins = ["some.user@org.com"] # must be in the list of workspace users

  metastore_grants = {
    "some.user@org.com" = [
      "CREATE_CATALOG",
    ]
  }

  storage = {
    subnet = "OZ" # Subnet for private endpoints

    data_share_access = [
      "some.user@org.com",
    ]
  }
}