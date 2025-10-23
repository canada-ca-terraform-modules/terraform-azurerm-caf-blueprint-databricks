provider "databricks" {
  alias = "dbw"
  host = azurerm_databricks_workspace.this.workspace_url
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

  depends_on = [ databricks_metastore_assignment.this ]
}

data "databricks_current_user" "me" {
  provider = databricks.dbw
}

data "databricks_group" "account_admins" {

  display_name = var.databricks_config.account_admins_group_name

  provider = databricks.azure_account
}

resource "databricks_permission_assignment" "account-admins-are-workspace-admins" {

  principal_id = data.databricks_group.account_admins.id
  permissions = ["ADMIN"]

  provider = databricks.dbw
  
  depends_on = [ terraform_data.workspace-private-endpoint-resolved-ip ]
}

resource "databricks_permission_assignment" "current-user-is-workspace-admin" {
  
  principal_id = data.databricks_current_user.me.id
  permissions = ["ADMIN"]

  provider = databricks.dbw
  depends_on = [ terraform_data.workspace-private-endpoint-resolved-ip ]
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
  
  workspace_access = try(each.value.user.workspace_access, true)
  
  depends_on = [ 
    databricks_permission_assignment.current-user-is-workspace-admin
  ]

  provider = databricks.dbw

}

data "databricks_group" "builtin-admins" {
  display_name = "admins"

  provider = databricks.dbw

  depends_on = [ 
    databricks_permission_assignment.current-user-is-workspace-admin
  ]
}

resource "databricks_group_member" "workspace-admins" {
  for_each = toset(var.databricks_workspace.workspace_admins)

  group_id  = data.databricks_group.builtin-admins.id
  member_id = databricks_user.workspace_users[each.value].id

  provider = databricks.dbw

  depends_on = [ 
    databricks_permission_assignment.current-user-is-workspace-admin
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
    databricks_permission_assignment.current-user-is-workspace-admin
  ]
}

resource "databricks_external_location" "catalog" {

  name = lower("${var.databricks_workspace.name}-catalog-el")
  url = format("abfss://%s@%s.dfs.core.windows.net/", azurerm_storage_container.catalog.name, module.databricks-storage-account.name )
  credential_name = databricks_storage_credential.connector.name

  owner = data.databricks_group.account_admins.display_name

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  provider = databricks.dbw
  depends_on = [ 
    azurerm_storage_container.catalog, 
    databricks_permission_assignment.current-user-is-workspace-admin
  ]
}

resource "databricks_external_location" "data" {

  name = lower("${var.databricks_workspace.name}-data-el")
  url = format("abfss://%s@%s.dfs.core.windows.net/", azurerm_storage_container.data.name, module.databricks-storage-account.name )
  credential_name = databricks_storage_credential.connector.name

  owner = data.databricks_group.account_admins.display_name

  isolation_mode = "ISOLATION_MODE_ISOLATED"

  provider = databricks.dbw
  depends_on = [ 
    azurerm_storage_container.catalog, 
    databricks_permission_assignment.current-user-is-workspace-admin
  ]
}

resource "databricks_catalog" "default_catalog" {
  
  metastore_id = var.databricks_config.metastore_id
  name = "${var.databricks_workspace.name}_default_catalog"
  owner = data.databricks_group.account_admins.display_name
    
  storage_root = databricks_external_location.catalog.url
  
  isolation_mode = "ISOLATED"

  provider = databricks.dbw

  depends_on = [ 
    databricks_permission_assignment.current-user-is-workspace-admin
  ]

}