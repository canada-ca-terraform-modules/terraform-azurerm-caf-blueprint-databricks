module "databricks-storage-account" {
  source   = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-storage_accountV2.git?ref=v1.0.5"
  
  userDefinedString = "${var.databricks_workspace.name}-sa"

  location = var.location
  env = var.env
  resource_groups = local.resource_groups
  storage_account = {                           # Key defines the userDefinedString
    resource_group           = var.databricks_workspace.resource_group  # Required: Resource group name, i.e Project, Management, DNS, etc, or the resource group ID
    account_tier             = "Standard" # Required: Possible values: Standard,Premium
    account_replication_type = "LRS"      # Required: Possible values: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS

    account_kind                     = "StorageV2"   # Optional: possible values: BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2. Default: StorageV2
    access_tier                      = "Hot"         # Optional: Possible values: Hot, Cool. Default: Hot
    public_network_access_enabled    = false         # Optional: Possible values: true, false. Default: false
    allow_nested_items_to_be_public  = false         # Optional: Possible values: true, false. Default: false. Can uncomment to set this value
    is_hns_enabled                   = true       # Optional: Possible values: true, false. Default: false. Can uncomment to set this value

    # Optional: Defines a private endpoint for the storage account
    # Can be commented out if no private endpoint is required
    private_endpoint = {
      dfs = {                                                  # Key defines the userDefinedstring
        resource_group    = var.databricks_workspace.resource_group          # Required: Resource group name, i.e Project, Management, DNS, etc, or the resource group ID
        subnet            = var.databricks_workspace.storage.subnet           # Required: Subnet name, i.e OZ,MAZ, etc, or the subnet ID
        subresource_names = ["dfs"]                            # Required: Subresource name determines to what service the private endpoint will connect to. see: https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource for list of subresrouce
        # local_dns_zone    = "privatelink.blob.core.windows.net" # Optional: Name of the local DNS zone for the private endpoint
      }
      blob = {                                                  # Key defines the userDefinedstring
        resource_group    = var.databricks_workspace.resource_group           # Required: Resource group name, i.e Project, Management, DNS, etc, or the resource group ID
        subnet            = var.databricks_workspace.storage.subnet           # Required: Subnet name, i.e OZ,MAZ, etc, or the subnet ID
        subresource_names = ["blob"]                            # Required: Subresource name determines to what service the private endpoint will connect to. see: https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource for list of subresrouce
        # local_dns_zone    = "privatelink.blob.core.windows.net" # Optional: Name of the local DNS zone for the private endpoint
      }
    }
  }
  subnets = var.subnets
  tags = var.tags  
}

data "azuread_user" "storage_account_contributors" {
  for_each = {
    for user in var.databricks_workspace.storage.data_share_access:
      "${user}" => user
  }

  mail = each.value
}

resource "azurerm_role_assignment" "data_share_access" {
  for_each = { 
    for key, user in data.azuread_user.storage_account_contributors: 
      key => {
        object_id = user.object_id
        scope = module.databricks-storage-account.id
      } 
  }

  scope                = each.value.scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.object_id
}

resource "azurerm_storage_container" "base-containers" {

  for_each = toset(["catalog", "data"])

  name = each.key
  storage_account_id = module.databricks-storage-account.id
}
