provider "databricks" {
  alias = "dbw"
  host = azapi_resource.databricks.output.properties.workspaceUrl
}

data "databricks_current_user" "me" {
  provider = databricks.dbw
}

data "databricks_group" "account_admins_in_workspace" {
  provider = databricks.dbw

  display_name = var.databricks_config.account_admins_group_name
  depends_on = [ 
    databricks_mws_permission_assignment.account-admins-are-workspace-admins 
  ]
}

# resource "databricks_permission_assignment" "current-user-is-workspace-admin" {
  
#   principal_id = data.databricks_current_user.me.id
#   permissions = ["ADMIN"]

#   provider = databricks.dbw
# }

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
  
  workspace_access = try(each.value.user.workspace_access, true)
  
  depends_on = [ databricks_metastore_assignment.this ]

  provider = databricks.dbw

}

data "databricks_group" "builtin-admins" {
  display_name = "admins"

  provider = databricks.dbw

  depends_on = [ databricks_mws_permission_assignment.account-admins-are-workspace-admins ]
}

resource "databricks_group_member" "workspace-admins" {
  for_each = toset(var.databricks_workspace.workspace_admins)

  group_id  = data.databricks_group.builtin-admins.id
  member_id = databricks_user.workspace_users[each.value].id

  provider = databricks.dbw

  depends_on = [ 
    databricks_metastore_assignment.this
  ]
}

resource "databricks_storage_credential" "connector" {

  name = lower("${azurerm_databricks_access_connector.connector.name}-sc")
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.connector.id
  }

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  provider = databricks.dbw
  depends_on = [ 
    azurerm_databricks_access_connector.connector,
    databricks_metastore_assignment.this
  ]
}

resource "databricks_grant" "account_admins_can_manage_credential" {
  
  storage_credential = databricks_storage_credential.connector.id

  principal = data.databricks_group.account_admins_in_workspace.display_name
  privileges = ["MANAGE"]

  provider = databricks.dbw

  depends_on = [ 
    databricks_metastore_assignment.this
  ]
}

resource "databricks_external_location" "base-locations" {

  for_each = { for container in local.base_storage_containers :
    container => azurerm_storage_container.base-containers[container]
    if lookup(azurerm_storage_container.base-containers, container, null) != null
  } 

  name = lower("${var.databricks_workspace.name}-${each.key}-el")
  url = format("abfss://%s@%s.dfs.core.windows.net/", each.key, module.databricks-storage-account.name )
  credential_name = databricks_storage_credential.connector.name

  owner = data.databricks_current_user.me.user_name

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  provider = databricks.dbw
  depends_on = [ 
    azurerm_storage_container.base-containers, 
    databricks_metastore_assignment.this
  ]
}

resource "databricks_grant" "account_admins_can_manage_external_locations" {
for_each = { 
  for container in local.base_storage_containers : 
    container => databricks_external_location.base-locations[container] 
    if lookup(databricks_external_location.base-locations, container, null) != null
  }

  external_location = each.value.id

  principal = data.databricks_group.account_admins_in_workspace.display_name
  privileges = ["MANAGE"]

  provider = databricks.dbw
  depends_on = [ 
    databricks_metastore_assignment.this
  ]
}

resource "databricks_catalog" "default_catalog" {
  
  metastore_id = var.databricks_config.metastore_id
  name = "${var.databricks_workspace.name}_default_catalog"
  owner = data.databricks_current_user.me.user_name
    
  storage_root = databricks_external_location.base-locations["catalog"].url
  
  isolation_mode = "ISOLATED"

  provider = databricks.dbw

  depends_on = [ 
    databricks_metastore_assignment.this
  ]

}

resource "databricks_grant" "account_admins_can_manage_default_catalog" {
  
  catalog = databricks_catalog.default_catalog.id

  principal = data.databricks_group.account_admins_in_workspace.display_name
  privileges = ["MANAGE"]

  provider = databricks.dbw

  depends_on = [ 
    databricks_metastore_assignment.this
  ]
}