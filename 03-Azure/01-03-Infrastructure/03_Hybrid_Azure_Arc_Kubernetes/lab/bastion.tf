# ==============================================================================
# Central Azure Bastion for secure RDP/SSH access to all participant VMs.
# Uses Standard SKU with IP-based connection to reach VMs across peered VNets.
# ==============================================================================

# --- Bastion Resource Group ---

resource "azurerm_resource_group" "bastion" {
  name     = "mh-bastion"
  location = var.bastion_location
  tags     = { "SecurityControl" = "Ignore" }
}

# --- Bastion VNet ---

resource "azurerm_virtual_network" "bastion" {
  name                = "mh-bastion-vnet"
  address_space       = [var.bastion_vnet_address_space]
  location            = azurerm_resource_group.bastion.location
  resource_group_name = azurerm_resource_group.bastion.name

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# Azure Bastion requires a subnet named exactly "AzureBastionSubnet"
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.bastion.name
  virtual_network_name = azurerm_virtual_network.bastion.name
  address_prefixes     = [cidrsubnet(var.bastion_vnet_address_space, 8, 0)] # /24
}

# --- Bastion Public IP ---

resource "azurerm_public_ip" "bastion" {
  name                = "mh-bastion-ip"
  resource_group_name = azurerm_resource_group.bastion.name
  location            = azurerm_resource_group.bastion.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# --- Azure Bastion Host (Standard SKU) ---

resource "azurerm_bastion_host" "bastion" {
  name                = "mh-bastion"
  resource_group_name = azurerm_resource_group.bastion.name
  location            = azurerm_resource_group.bastion.location
  sku                 = "Standard"

  # Required for cross-VNet connections via peering
  ip_connect_enabled     = true
  tunneling_enabled      = true
  shareable_link_enabled = false

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# --- Global VNet Peering: Bastion <-> each participant VNet ---

resource "azurerm_virtual_network_peering" "bastion_to_onprem" {
  count                        = length(local.indices)
  name                         = "bastion-to-${format("%02d", local.indices[count.index])}-onprem"
  resource_group_name          = azurerm_resource_group.bastion.name
  virtual_network_name         = azurerm_virtual_network.bastion.name
  remote_virtual_network_id    = azurerm_virtual_network.onprem[count.index].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "onprem_to_bastion" {
  count                        = length(local.indices)
  name                         = "${format("%02d", local.indices[count.index])}-onprem-to-bastion"
  resource_group_name          = azurerm_resource_group.mh_k8s_onprem[count.index].name
  virtual_network_name         = azurerm_virtual_network.onprem[count.index].name
  remote_virtual_network_id    = azurerm_virtual_network.bastion.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# --- Outputs ---

output "bastion_name" {
  value = azurerm_bastion_host.bastion.name
}

output "bastion_resource_group" {
  value = azurerm_resource_group.bastion.name
}
