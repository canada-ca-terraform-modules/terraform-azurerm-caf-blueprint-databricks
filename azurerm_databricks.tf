data "azapi_client_config" "current" {
}

resource "azapi_resource" "databricks" {
  name      = "${var.env}-${var.group}-${var.project}-${var.databricks_workspace.name}-dbw"
  type      = "Microsoft.Databricks/workspaces@2025-08-01-preview"
  location  = var.location
  parent_id = module.databricks-rg.id
  tags = var.tags

  body = {
    sku = {
        name = try(var.databricks_workspace.sku, "premium")
      }
    properties = {
      managedResourceGroupId = "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${var.databricks_workspace.name}-${module.databricks-rg.name}"
      #computeMode = "Hybrid"
      enhancedSecurityCompliance = {
        automaticClusterUpdate = {
          value = "Enabled"
        }
        complianceSecurityProfile = {
          complianceStandards = [
            "CANADA_PROTECTED_B"
          ]
          value = "Enabled"
        }
        enhancedSecurityMonitoring = {
          value = "Enabled"
        }
      }
      requiredNsgRules = "NoAzureDatabricksRules"
      publicNetworkAccess = "Enabled"
      parameters = { 
        
        customPrivateSubnetName = {
          type = "String"
          value = var.subnets[var.databricks_workspace.private_subnet].object.name
        }
        customPublicSubnetName = {
          type = "String"
          value = var.subnets[var.databricks_workspace.public_subnet].object.name
        }
        customVirtualNetworkId = {
          type = "String"
          value = var.vnet.id
        }
        enableNoPublicIp = {
          type = "Bool"
          value = true
        }
      }
      
    }
    
  }

  response_export_values = ["*"]

  lifecycle {
    ignore_changes = [ body.properties.publicNetworkAccess ]
  }
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
  name = azapi_resource.databricks.output.name
  location = azapi_resource.databricks.output.location
  private_connection_resource_id = azapi_resource.databricks.id
  tags = var.tags

  depends_on = [ azapi_resource.databricks ]

}

resource "azurerm_databricks_access_connector" "connector" {
  name                = "${azapi_resource.databricks.name}-con"
  resource_group_name = module.databricks-rg.name
  location            = azapi_resource.databricks.output.location

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

