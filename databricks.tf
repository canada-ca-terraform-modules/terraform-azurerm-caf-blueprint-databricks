locals {
  resource_groups = merge(var.resource_groups, { "${var.databricks_workspace.resource_group}" = module.databricks-rg })
}

module "databricks-rg" {
  source = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-resource_groups.git?ref=v2.0.1"

  userDefinedString = var.databricks_workspace.resource_group
  env = var.env
  location = var.location
  group = var.group
  project = var.project
  resource_group = {}
  tags = var.tags
}

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
  subnets = local.subnets
  private_dns_zone_ids = local.Project-dns-zone
  tags = var.tags  
}

resource "azurerm_databricks_workspace" "this" {

  name                        = "${var.env}-${var.group}-${var.project}-${var.databricks_workspace.name}-dbw"
  resource_group_name         = module.databricks-rg.name
  location                    = module.databricks-rg.location
  sku                         = try(var.databricks_workspace.sku, "premium")
  
  #TODO: use our naming for the managed RG as well. Can't be the same as the workspace RG
  managed_resource_group_name = "${var.databricks_workspace.name}-${module.databricks-rg.name}"

  public_network_access_enabled = false
  network_security_group_rules_required = "NoAzureDatabricksRules"

  tags                        = var.tags

  custom_parameters {
    # no_public_ip                                         = false
    virtual_network_id                                   = local.Project-vnet.id
    
    private_subnet_network_security_group_association_id = var.subnets[var.databricks_workspace.private_subnet].id
    private_subnet_name                                  = var.subnets[var.databricks_workspace.private_subnet].object.name

    public_subnet_network_security_group_association_id  = var.subnets[var.databricks_workspace.public_subnet].id
    public_subnet_name                                   = var.subnets[var.databricks_workspace.public_subnet].object.name
  }

  # https://learn.microsoft.com/en-us/azure/databricks/security/privacy/security-profile
  # enhanced_security_compliance {
  #   compliance_security_profile_enabled = true
  #   compliance_security_profile_standards = ["HIPAA", "PCI_DSS"]
  #   automatic_cluster_update_enabled = false
  #   enhanced_security_monitoring_enabled = false
  # }
}

module "databricks-pe" {
  source = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-private_endpoint?ref=v1.0.2"

  private_endpoint = {
    resource_group = var.databricks_workspace.resource_group
    subnet = var.databricks_workspace.pe_subnet
    subresource_names = ["databricks_ui_api"]
  }

  resource_groups = local.resource_groups
  subnets = local.subnets
  name = azurerm_databricks_workspace.this.name
  location = azurerm_databricks_workspace.this.location
  private_connection_resource_id = azurerm_databricks_workspace.this.id
  tags = var.tags

  depends_on = [ azurerm_databricks_workspace.this ]

}

resource "terraform_data" "workspace-private-endpoint-resolved-ip" {
  
  input = {
    local_ip = module.databricks-pe.private-endpoint-object.private_service_connection[0].private_ip_address
    workspace_fqdn = azurerm_databricks_workspace.this.workspace_url
  }

  provisioner "local-exec" {
    environment = {
      url = azurerm_databricks_workspace.this.workspace_url
      expected_ip = module.databricks-pe.private-endpoint-object.private_service_connection[0].private_ip_address
    }

    when = create

    command = <<-EOT
    timeout_seconds=2000 # DNS TTL is 1800s, and Private DNS takes a few minutes to deploy
    sleep_seconds=30

    while [ $timeout_seconds -gt 0 ]; do
      ip=$(getent hosts $url | awk '{ print $1 }')
      timeout_seconds=$((timeout_seconds - sleep_seconds))

      if [ "$ip" = "$expected_ip" ]; then
        echo "$ip is looked up correctly. Ok to proceed with workspace configuration."
        exit 0
      fi
      echo "Resolved as $ip instead of $expected_ip. Sleeping for $sleep_seconds seconds."
      sleep $sleep_seconds
    done
    echo "Timeout of $sleep_seconds seconds reached"
    exit 1
EOT
  }
}

resource "azurerm_databricks_access_connector" "connector" {
  name                = "${azurerm_databricks_workspace.this.name}-con"
  resource_group_name = azurerm_databricks_workspace.this.resource_group_name
  location            = azurerm_databricks_workspace.this.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "databricks-connector-to-storage" {
  scope                = module.databricks-storage-account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.connector.identity[0].principal_id
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

resource "azurerm_storage_container" "catalog" {
  name = "catalog"
  storage_account_id = module.databricks-storage-account.id
}

resource "azurerm_storage_container" "data" {
  name = "data"
  storage_account_id = module.databricks-storage-account.id
}

/* Begin Account-level assignments */

provider "databricks" {
  alias = "azure_account"
  host = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_config.account_id
}

data "databricks_group" "account_admins" {

  display_name = "Account Admins" # This value is specific to our tenant

  provider = databricks.azure_account
}

resource "databricks_metastore_assignment" "this" {

  metastore_id = var.databricks_config.metastore_id
  workspace_id = azurerm_databricks_workspace.this.workspace_id

  provider = databricks.azure_account

  depends_on = [ azurerm_databricks_workspace.this, module.databricks-pe ]
}

resource "databricks_mws_permission_assignment" "account-admins-are-workspace-admins" {

  workspace_id = azurerm_databricks_workspace.this.workspace_id
  principal_id = data.databricks_group.account_admins.id
  permissions = ["ADMIN"]

  provider = databricks.azure_account
  depends_on = [ databricks_metastore_assignment.this ]
}

/* End Account-level assignments */

/* Workspace-level */

# # this needs OpenTofu so we can do a for_each
provider "databricks" {
  alias = "dbw"
  host = azurerm_databricks_workspace.this.workspace_url
}

resource "databricks_user" "workspace_users" {
  for_each = {
    for username, user in var.databricks_workspace.workspace_users:
      "${username}" => {
        username = username
        user = user
      }
  }

  user_name    = each.value.username

  display_name = try(each.value.user.display_name, null)
  external_id = try(each.value.user.external_id, null)
  allow_cluster_create = try(each.value.user.allow_cluster_create, false)
  allow_instance_pool_create = try(each.value.user.allow_instance_pool_create, false)
  databricks_sql_access = try(each.value.user.databricks_sql_access, null)
  active = try(each.value.user.active, true)
  force = try(each.value.user.force, null)

  force_delete_repos = try(each.value.user.force_delete_repos, false)
  force_delete_home_dir = try(each.value.user.force_delete_home_dir, false)
  
  workspace_access = try(each.value.user.workspace_access, false)
  
  depends_on = [ databricks_mws_permission_assignment.account-admins-are-workspace-admins, terraform_data.workspace-private-endpoint-resolved-ip ]

  provider = databricks.dbw

}

data "databricks_group" "builtin-admins" {
  display_name = "admins"

  provider = databricks.dbw

  depends_on = [ databricks_mws_permission_assignment.account-admins-are-workspace-admins, terraform_data.workspace-private-endpoint-resolved-ip ]
}

resource "databricks_group_member" "workspace-admins" {
  for_each = toset(var.databricks_workspace.workspace_admins)

  group_id  = data.databricks_group.builtin-admins.id
  member_id = databricks_user.workspace_users[each.value].id

  provider = databricks.dbw

  depends_on = [ databricks_mws_permission_assignment.account-admins-are-workspace-admins, terraform_data.workspace-private-endpoint-resolved-ip ]
}

resource "databricks_grant" "sandbox" {
  for_each = var.databricks_workspace.metastore_grants

  metastore = var.databricks_config.metastore_id

  principal = each.key
  privileges = each.value

  provider = databricks.dbw

  depends_on = [ databricks_mws_permission_assignment.account-admins-are-workspace-admins, terraform_data.workspace-private-endpoint-resolved-ip ]
}

resource "databricks_storage_credential" "connector" {

  name = lower("${azurerm_databricks_access_connector.connector.name}-sc")
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.connector.id
  }

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  provider = databricks.dbw
  depends_on = [ azurerm_databricks_access_connector.connector, databricks_mws_permission_assignment.account-admins-are-workspace-admins, terraform_data.workspace-private-endpoint-resolved-ip ]
}

resource "databricks_external_location" "catalog" {

  name = lower("${var.databricks_workspace.name}-catalog-el")
  url = format("abfss://%s@%s.dfs.core.windows.net/", azurerm_storage_container.catalog.name, module.databricks-storage-account.name )
  credential_name = databricks_storage_credential.connector.name

  owner = data.databricks_group.account_admins.display_name

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  provider = databricks.dbw
  depends_on = [ azurerm_storage_container.catalog, databricks_mws_permission_assignment.account-admins-are-workspace-admins, terraform_data.workspace-private-endpoint-resolved-ip ]
}

resource "databricks_external_location" "data" {

  name = lower("${var.databricks_workspace.name}-data-el")
  url = format("abfss://%s@%s.dfs.core.windows.net/", azurerm_storage_container.data.name, module.databricks-storage-account.name )
  credential_name = databricks_storage_credential.connector.name

  owner = data.databricks_group.account_admins.display_name

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  provider = databricks.dbw
  depends_on = [ azurerm_storage_container.catalog, databricks_mws_permission_assignment.account-admins-are-workspace-admins, terraform_data.workspace-private-endpoint-resolved-ip ]
}

resource "databricks_catalog" "default_catalog" {
  
  metastore_id = var.databricks_config.metastore_id
  name = "${var.databricks_workspace.name}_default_catalog"
  owner = data.databricks_group.account_admins.display_name
    
  storage_root = databricks_external_location.catalog.url
  
  isolation_mode = "ISOLATED"

  provider = databricks.dbw

  depends_on = [ databricks_mws_permission_assignment.account-admins-are-workspace-admins, terraform_data.workspace-private-endpoint-resolved-ip ]

}

resource "databricks_grant" "admins-can-manage-default-catalog" {

  catalog = databricks_catalog.default_catalog.name

  principal = data.databricks_group.account_admins.display_name
  privileges = ["USE_CATALOG", "MANAGE"]

  provider = databricks.dbw

  depends_on = [ databricks_catalog.default_catalog ]
}