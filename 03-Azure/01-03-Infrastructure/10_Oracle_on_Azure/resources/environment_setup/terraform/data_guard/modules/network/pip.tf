#########################################################################################
#                                                                                       #
#  Public IPs                                                                                  #
#                                                                                       #
#########################################################################################

resource "azurerm_public_ip" "vm_pip" {
  count               = var.is_data_guard ? 2 : 1
  name                = "vmpip-${count.index}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.tags, var.tags)
}

data "azurerm_public_ip" "vm_pip" {
  count               = var.is_data_guard ? 2 : 1
  name                = "vmpip-${count.index}"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_public_ip.vm_pip]
}
