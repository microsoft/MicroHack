# ===============================================================================
# VNet Peering Module - Main Configuration
# ===============================================================================
# This module creates bidirectional VNet peering between AKS and ODAA networks
# across different Azure subscriptions.
# ===============================================================================

terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.aks, azurerm.odaa]
    }
  }
}

# ===============================================================================
# VNet Peering: AKS to ODAA
# ===============================================================================

resource "azurerm_virtual_network_peering" "aks_to_odaa" {
  provider                  = azurerm.aks
  name                      = var.peering_suffix != "" ? "peer-aks-to-odaa-${var.peering_suffix}" : "peer-aks-to-odaa"
  resource_group_name       = var.aks_resource_group
  virtual_network_name      = var.aks_vnet_name
  remote_virtual_network_id = var.odaa_vnet_id

  # Peering settings
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  # Peering can be destroyed independently of subnets
  # This prevents blocking subnet deletion
  lifecycle {
    create_before_destroy = false
  }
}

# ===============================================================================
# VNet Peering: ODAA to AKS
# ===============================================================================

resource "azurerm_virtual_network_peering" "odaa_to_aks" {
  provider                  = azurerm.odaa
  name                      = var.peering_suffix != "" ? "peer-odaa-to-aks-${var.peering_suffix}" : "peer-odaa-to-aks"
  resource_group_name       = var.odaa_resource_group
  virtual_network_name      = var.odaa_vnet_name
  remote_virtual_network_id = var.aks_vnet_id

  # Peering settings
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  # Peering can be destroyed independently of subnets
  # This prevents blocking subnet deletion
  lifecycle {
    create_before_destroy = false
  }
}