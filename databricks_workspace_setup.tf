provider "databricks" {
  #alias = "dbw"
  host = azurerm_databricks_workspace.databricks.workspace_url
}

variable "ignore_metastore" {
  type = bool
  default = false
}

data "databricks_current_metastore" "this" {
  # provider = databricks.dbw 

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
}

locals {
  workspace_is_joined = var.ignore_metastore ? false : (data.databricks_current_metastore.this.id != "no_metastore")
}

data "databricks_current_user" "me" {
  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
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
  allow_cluster_create = try(each.value.user.allow_cluster_create, null)
  allow_instance_pool_create = try(each.value.user.allow_instance_pool_create, null)
  databricks_sql_access = try(each.value.user.databricks_sql_access, null)
  
  active = try(each.value.user.active, null)
  force = try(each.value.user.force, null)

  force_delete_repos = try(each.value.user.force_delete_repos, null)
  force_delete_home_dir = try(each.value.user.force_delete_home_dir, null)
  
  workspace_access = try(each.value.user.workspace_access, true)
  workspace_consume = try(each.value.user.workspace_consume, null)

  depends_on = [ azurerm_databricks_workspace.databricks ]
  # provider = databricks.dbw
}

data "databricks_group" "builtin-admins" {
  display_name = "admins"

  # provider = databricks.dbw
  
  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
}

data "azuread_group" "account-admins" {
  display_name = var.databricks_config.account_admins_group_name
}

resource "databricks_group" "account-admins" {
  count = local.workspace_is_joined ? 1 : 0

  display_name = data.azuread_group.account-admins.display_name
  external_id = data.azuread_group.account-admins.object_id
  
  depends_on = [ 
    azurerm_databricks_workspace.databricks,
    data.azuread_group.account-admins
  ]
}

resource "databricks_group_member" "account-admins-are-workspace-admins" {
  count = local.workspace_is_joined ? 1 : 0

  group_id  = data.databricks_group.builtin-admins.id
  member_id = databricks_group.account-admins[0].id

  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
    databricks_group.account-admins
  ]
}

resource "databricks_group_member" "workspace-admins" {
  for_each = toset(var.databricks_workspace.workspace_admins)

  group_id  = data.databricks_group.builtin-admins.id
  member_id = databricks_user.workspace_users[each.value].id

  # provider = databricks.dbw
}

resource "databricks_storage_credential" "connector" {

  count = local.workspace_is_joined ? 1 : 0

  name = lower("${azurerm_databricks_access_connector.connector.name}-sc")
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.connector.id
  }

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
    azurerm_databricks_access_connector.connector,    
  ]

  lifecycle {  
    ignore_changes = [
      owner
    ]
  }
}

resource "databricks_grant" "account_admins_can_manage_credential" {
  
  count = local.workspace_is_joined ? 1 : 0

  storage_credential = databricks_storage_credential.connector[0].name

  principal =  databricks_group.account-admins[0].display_name
  privileges = ["MANAGE"]

  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
    databricks_group.account-admins
  ]
}

resource "databricks_external_location" "base-locations" {

  for_each = { for container in local.base_storage_containers :
    container => azurerm_storage_container.base-containers[container]
    if local.workspace_is_joined
  } 

  name = lower("${azurerm_databricks_workspace.databricks.name}-${each.key}-el")
  url = format("abfss://%s@%s.dfs.core.windows.net/", each.key, module.databricks-storage-account.name )
  credential_name = databricks_storage_credential.connector[0].name

  owner = data.databricks_current_user.me.user_name

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  # provider = databricks.dbw
  depends_on = [ 
    azurerm_databricks_workspace.databricks,
    azurerm_storage_container.base-containers
  ]

  lifecycle {  
    ignore_changes = [
      owner
    ]
  }
}

resource "databricks_grant" "account_admins_can_manage_external_locations" {
  
  for_each = { for container in local.base_storage_containers :
    container => azurerm_storage_container.base-containers[container]
    if local.workspace_is_joined
  }

  external_location = databricks_external_location.base-locations[each.key].name

  principal = databricks_group.account-admins[0].display_name
  privileges = ["MANAGE"]

  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
    databricks_group.account-admins
  ]
}

resource "databricks_catalog" "default_catalog" {
  
  count = local.workspace_is_joined ? 1 : 0

  metastore_id = var.databricks_config.metastore_id
  name = "${azurerm_databricks_workspace.databricks.name}_default_catalog"
  owner = data.databricks_current_user.me.user_name
    
  storage_root = databricks_external_location.base-locations["catalog"].url
  
  isolation_mode = "ISOLATED"

  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]

  lifecycle {  
    ignore_changes = [
      owner
    ]
  }
}

resource "databricks_grant" "account_admins_can_manage_default_catalog" {
 
  count = local.workspace_is_joined ? length(databricks_catalog.default_catalog) : 0

  catalog = databricks_catalog.default_catalog[count.index].name

  principal = databricks_group.account-admins[0].display_name
  privileges = ["MANAGE"]

  # provider = databricks.dbw
  
  depends_on = [ 
    azurerm_databricks_workspace.databricks,
    databricks_group.account-admins
  ]

}