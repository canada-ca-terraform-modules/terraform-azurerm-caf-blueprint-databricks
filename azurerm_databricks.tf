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
    virtual_network_id                                   = var.vnet.id
    
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
  subnets = var.subnets
  name = azurerm_databricks_workspace.this.name
  location = azurerm_databricks_workspace.this.location
  private_connection_resource_id = azurerm_databricks_workspace.this.id
  tags = var.tags

  depends_on = [ azurerm_databricks_workspace.this ]

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

