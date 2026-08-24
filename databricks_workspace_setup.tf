provider "databricks" {
  #alias = "dbw"
  host = azurerm_databricks_workspace.databricks.workspace_url
}

data "databricks_current_metastore" "this" {
  # provider = databricks.dbw 

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
}

resource "terraform_data" "databricks_workspace_is_joined" {
  input = {
    metastore_id = data.databricks_current_metastore.this.id
  }

  depends_on = [ azurerm_databricks_workspace.databricks ]
}

locals {
  workspace_is_joined = try(terraform_data.databricks_workspace_is_joined.output.id != "no_metastore", false)
}

data "databricks_current_user" "me" {
  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
}

data "databricks_group" "account_admins" {
  count = local.workspace_is_joined ? 1 : 0
  # provider = databricks.dbw

  display_name = var.databricks_config.account_admins_group_name

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
}

# resource "databricks_permission_assignment" "current-user-is-workspace-admin" {
  
#   principal_id = data.databricks_current_user.me.id
#   permissions = ["ADMIN"]

#   # provider = databricks.dbw
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

resource "databricks_group_member" "workspace-admins" {
  for_each = local.workspace_is_joined ? toset(var.databricks_workspace.workspace_admins) : toset([])

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

}

resource "databricks_grant" "account_admins_can_manage_credential" {
  
  for_each = { 
    for k, v in databricks_storage_credential.connector: 
      v.name => v.id
  }

  storage_credential = each.value

  principal = data.databricks_group.account_admins[0].display_name
  privileges = ["MANAGE"]

  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
}

resource "databricks_external_location" "base-locations" {

  for_each = { for container in local.base_storage_containers :
    container => azurerm_storage_container.base-containers[container]
    if local.workspace_is_joined && lookup(azurerm_storage_container.base-containers, container, null) != null
  } 

  name = lower("${var.databricks_workspace.name}-${each.key}-el")
  url = format("abfss://%s@%s.dfs.core.windows.net/", each.key, module.databricks-storage-account.name )
  credential_name = databricks_storage_credential.connector[0].name

  owner = data.databricks_current_user.me.user_name

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  # provider = databricks.dbw
  depends_on = [ 
    azurerm_databricks_workspace.databricks,
    azurerm_storage_container.base-containers
  ]

}

resource "databricks_grant" "account_admins_can_manage_external_locations" {
for_each = { 
  for container in local.base_storage_containers : 
    container => databricks_external_location.base-locations[container] 
    if lookup(databricks_external_location.base-locations, container, null) != null
  }

  external_location = each.value.id

  principal = data.databricks_group.account_admins[0].display_name
  privileges = ["MANAGE"]

  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
}

resource "databricks_catalog" "default_catalog" {
  
  count = local.workspace_is_joined ? 1 : 0

  metastore_id = var.databricks_config.metastore_id
  name = "${var.databricks_workspace.name}_default_catalog"
  owner = data.databricks_current_user.me.user_name
    
  storage_root = databricks_external_location.base-locations["catalog"].url
  
  isolation_mode = "ISOLATED"

  # provider = databricks.dbw

  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]
}

resource "databricks_grant" "account_admins_can_manage_default_catalog" {
  
  for_each = {
    for k, v in databricks_catalog.default_catalog : 
      v.name => v.id
  }

  catalog = each.value

  principal = data.databricks_group.account_admins[0].display_name
  privileges = ["MANAGE"]

  # provider = databricks.dbw
  
  depends_on = [ 
    azurerm_databricks_workspace.databricks,
  ]

}