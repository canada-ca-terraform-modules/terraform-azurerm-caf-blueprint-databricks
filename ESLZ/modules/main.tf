terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
       source  = "hashicorp/azuread"
       version = "~> 2.0"
    }
    databricks = {
      source = "databricks/databricks"
    }
    azapi = {
      source = "azure/azapi"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

provider "azuread" {
  
}

provider "azapi" {
  
}