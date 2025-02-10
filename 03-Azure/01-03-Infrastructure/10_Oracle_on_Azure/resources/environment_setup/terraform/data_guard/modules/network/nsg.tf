#########################################################################################
#                                                                                       #
#  Network Security Group                                                               #
#                                                                                       #
#########################################################################################
resource "azurerm_network_security_group" "blank" {
  name                = "blank"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  tags = merge(local.tags, var.tags)
}

resource "azurerm_subnet_network_security_group_association" "ssh" {
  subnet_id                 = data.azurerm_subnet.subnet_oracle[0].id
  network_security_group_id = azurerm_network_security_group.blank.id
}

data "azurerm_network_security_group" "blank" {
  name                = "blank"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_network_security_group.blank]
}


