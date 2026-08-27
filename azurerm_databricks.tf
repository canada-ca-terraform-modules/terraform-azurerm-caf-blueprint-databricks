resource "azurerm_databricks_workspace" "databricks" {
  name                = "${var.env}-${var.group}-${var.project}-${var.databricks_workspace.name}-dbw"
  resource_group_name = module.databricks-rg.name
  location            = var.location
  sku                 = try(var.databricks_workspace.sku, "premium")
  
  managed_resource_group_name = "${var.databricks_workspace.name}-${module.databricks-rg.name}"
  
  network_security_group_rules_required = "NoAzureDatabricksRules"
  
  # this gets disabled post deployment. It is kept enabled during provisioning to ensure continued connectivity while the private endpoint gets set up.
  public_network_access_enabled = true

  custom_parameters {
    no_public_ip = true

    virtual_network_id = var.vnet.id
    public_subnet_name = var.subnets[var.databricks_workspace.public_subnet].object.name
    public_subnet_network_security_group_association_id = var.subnets[var.databricks_workspace.public_subnet].object.id
    private_subnet_name = var.subnets[var.databricks_workspace.private_subnet].object.name
    private_subnet_network_security_group_association_id = var.subnets[var.databricks_workspace.private_subnet].object.id
  }

  enhanced_security_compliance {
    automatic_cluster_update_enabled = lookup(var.databricks_workspace, "protected_b", false)
    compliance_security_profile_enabled = lookup(var.databricks_workspace, "protected_b", false)
    compliance_security_profile_standards = lookup(var.databricks_workspace, "protected_b", false) ? ["CANADA_PROTECTED_B"] : null
    enhanced_security_monitoring_enabled = lookup(var.databricks_workspace, "protected_b", false)
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      public_network_access_enabled,
    ]
  }
}

module "databricks-pe" {
  source = "github.com/canada-ca-terraform-modules/terraform-azurerm-caf-private_endpoint?ref=v1.2.0"

  private_endpoint = {
    resource_group = var.databricks_workspace.resource_group
    subnet = var.databricks_workspace.pe_subnet
    subresource_names = ["databricks_ui_api"]
  }

  resource_groups = local.resource_groups
  subnets = var.subnets
  name = azurerm_databricks_workspace.databricks.name
  location = azurerm_databricks_workspace.databricks.location
  private_connection_resource_id = azurerm_databricks_workspace.databricks.id
  tags = var.tags

  depends_on = [ azurerm_databricks_workspace.databricks ]

}

resource "azurerm_databricks_access_connector" "connector" {
  name                = "${azurerm_databricks_workspace.databricks.name}-con"
  resource_group_name = module.databricks-rg.name
  location            = azurerm_databricks_workspace.databricks.location

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

