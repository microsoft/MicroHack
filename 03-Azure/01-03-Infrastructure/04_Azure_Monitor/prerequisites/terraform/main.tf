resource "azurerm_resource_group" "microhack_monitoring" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "microhack_law" {
  name                = "law-microhack"
  location            = azurerm_resource_group.microhack_monitoring.location
  resource_group_name = azurerm_resource_group.microhack_monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  depends_on = [ azurerm_resource_group.microhack_monitoring ]
}

module "virtual_machines" {
  source = "./modules/vms"
  subnet_id = azurerm_subnet.microhack_subnet[0].id

  depends_on = [ azurerm_resource_group.microhack_monitoring ]
}
  