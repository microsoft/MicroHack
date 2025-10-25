# ===============================================================================
# ODAA Module - Outputs
# ===============================================================================

output "resource_group_name" {
  description = "The name of the ODAA resource group"
  value       = azurerm_resource_group.odaa.name
}

output "resource_group_id" {
  description = "The ID of the ODAA resource group"
  value       = azurerm_resource_group.odaa.id
}

output "vnet_id" {
  description = "The ID of the ODAA virtual network"
  value       = azurerm_virtual_network.odaa.id
}

output "vnet_name" {
  description = "The name of the ODAA virtual network"
  value       = azurerm_virtual_network.odaa.name
}

output "subnet_id" {
  description = "The ID of the ODAA subnet"
  value       = azurerm_subnet.odaa.id
}

output "adb_id" {
  description = "The ID of the Oracle Autonomous Database"
  value       = length(azapi_resource.autonomous_database) > 0 ? azapi_resource.autonomous_database[0].id : null
}

output "adb_name" {
  description = "The name of the Oracle Autonomous Database"
  value       = length(azapi_resource.autonomous_database) > 0 ? azapi_resource.autonomous_database[0].name : null
}