
resource "azurerm_management_lock" "nsg" {
  count      = length(var.nsg_locks) > 1 && length(try(var.nsg_locks.name, "")) > 0 ? 1 : 0
  name       = var.nsg_locks.name
  scope      = data.azurerm_network_security_group.blank.id
  lock_level = var.nsg_locks.type

  depends_on = [azurerm_network_security_group.blank]
}

resource "azurerm_management_lock" "vnet" {
  count      = length(var.vnet_locks) > 1 && length(try(var.vnet_locks.name, "")) > 0 ? 1 : 0
  name       = var.vnet_locks.name
  scope      = data.azurerm_virtual_network.vnet_oracle[0].id
  lock_level = var.vnet_locks.type

  depends_on = [data.azurerm_virtual_network.vnet_oracle]
}

resource "azurerm_management_lock" "subnet" {
  count      = length(var.subnet_locks) > 1 && length(try(var.subnet_locks.name, "")) > 0 ? 1 : 0
  name       = var.subnet_locks.name
  scope      = data.azurerm_subnet.subnet_oracle[0].id
  lock_level = var.subnet_locks.type

  depends_on = [data.azurerm_subnet.subnet_oracle]
}
