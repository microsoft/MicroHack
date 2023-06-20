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


resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nic-assoc" {
  network_interface_id    = module.virtual_machines.vm_windows_nic_id
  ip_configuration_name   = "ipconfig-vm-windows"
  backend_address_pool_id = one(azurerm_application_gateway.appgw.backend_address_pool).id
}