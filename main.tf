terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    azuread = {
       source  = "hashicorp/azuread"
       version = "~> 2.0"
    }
    databricks = {
      source = "databricks/databricks"
    }
  }
}