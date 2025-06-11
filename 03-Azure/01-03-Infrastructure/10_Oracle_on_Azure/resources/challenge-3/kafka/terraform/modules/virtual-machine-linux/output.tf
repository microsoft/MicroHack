# # first interface

# output "interface_name" {
#   value = try(values(azurerm_network_interface.this)[0].name, null)
# }

# output "interface_id" {
#   value = values(azurerm_network_interface.this)[0].id
# }

# output "private_ip_address" {
#   value = values(azurerm_network_interface.this)[0].private_ip_address
# }

# output "private_ipv6_address" {
#   value = try(values(azurerm_network_interface.this)[0].private_ip_addresses[1], null)
# }

# output "public_ip_address" {
#   value = try(values(azurerm_public_ip.this)[0].ip_address, null)
# }

# output "public_ipv6_address" {
#   value = try(values(azurerm_public_ip.this_ipv6)[0].ip_address, null)
# }

# # other values

output "vm" {
  value = azurerm_linux_virtual_machine.vm
}

# output "interfaces" {
#   value = try(azurerm_network_interface.this, {})
# }

# output "interface_names" {
#   value = { for i in try(azurerm_network_interface.this, {}) : i.name => i.name }
# }

# output "interface_ids" {
#   value = { for i in try(azurerm_network_interface.this, {}) : i.name => i.id }
# }

# output "private_ip_addresses" {
#   value = { for i in try(azurerm_network_interface.this, {}) : i.name => i.private_ip_address }
# }

# # output "public_ip_addresses" {
# #   value = { for i in try(azurerm_network_interface.this, {}) : i.name => i.ip_configuration[0].public_ip_address }
# # }
