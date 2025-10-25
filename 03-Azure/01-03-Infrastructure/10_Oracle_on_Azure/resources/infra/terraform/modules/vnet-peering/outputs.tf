# ===============================================================================
# VNet Peering Module - Outputs
# ===============================================================================

output "aks_to_odaa_peering_id" {
  description = "The ID of the AKS to ODAA VNet peering"
  value       = azurerm_virtual_network_peering.aks_to_odaa.id
}

output "odaa_to_aks_peering_id" {
  description = "The ID of the ODAA to AKS VNet peering"
  value       = azurerm_virtual_network_peering.odaa_to_aks.id
}

output "aks_vnet_info" {
  description = "Information about the AKS virtual network"
  value = {
    id               = var.aks_vnet_id
    name             = var.aks_vnet_name
    resource_group   = var.aks_resource_group
  }
}

output "odaa_vnet_info" {
  description = "Information about the ODAA virtual network"
  value = {
    id               = var.odaa_vnet_id
    name             = var.odaa_vnet_name
    resource_group   = var.odaa_resource_group
  }
}