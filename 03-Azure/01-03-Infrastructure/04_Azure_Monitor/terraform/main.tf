provider "azurerm" {
  features {}
}

// Create a resource group
resource "azurerm_resource_group" "microhack_monitoring" {
  name     = var.rg_name
  location = var.location
}

// Creat Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "microhack_law" {
  name                = "microhack-law"
  location            = azurerm_resource_group.microhack_monitoring.location
  resource_group_name = azurerm_resource_group.microhack_monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}