###############################################################################
#                                                                             #
#                            Network                                          #
#                                                                             #
###############################################################################
output "network_location" {
  value = data.azurerm_virtual_network.vnet_oracle[0].location
}

output "db_subnet" {
  value = data.azurerm_subnet.subnet_oracle[0]
}

output "db_server_puplic_ip" {
  value = azurerm_public_ip.vm_pip[0].ip_address
}

output "db_server_puplic_ip_resources" {
  value = azurerm_public_ip.vm_pip
}
