resource "azurerm_public_ip" "pip_bastion" {
  name                = local.bastion_pip_name
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [ azurerm_resource_group.microhack_monitoring ]
}

resource "azurerm_bastion_host" "bastion" {
  name                = local.bastion_name
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.microhack_subnet_bastion.id
    public_ip_address_id = azurerm_public_ip.pip_bastion.id
  }
}

resource "azurerm_subnet" "microhack_subnet_bastion" {
  name                  = "AzureBastionSubnet"
  address_prefixes      = ["10.0.4.0/26"]
  virtual_network_name  = azurerm_virtual_network.microhack_vnet.name  
  resource_group_name   = azurerm_resource_group.microhack_monitoring.name
}