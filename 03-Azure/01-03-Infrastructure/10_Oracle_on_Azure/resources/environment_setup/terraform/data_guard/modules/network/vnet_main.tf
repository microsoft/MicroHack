module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.1.3"

  resource_group_name           = var.resource_group.name
  vnet_location                 = var.resource_group.location
  vnet_name                     = local.vnet_oracle_name
  virtual_network_address_space = [local.vnet_oracle_addr]
  subnets = {
    subnet1 = {
      address_prefixes = [local.database_subnet_prefix]
      azurerm_network_security_group = {
        id = azurerm_network_security_group.blank.id
      }
    }
  }

  tags = merge(local.tags, var.tags)
}


data "azurerm_virtual_network" "vnet_oracle" {
  count               = local.vnet_oracle_exists ? 0 : 1
  name                = local.vnet_oracle_name
  resource_group_name = var.resource_group.name

  depends_on = [module.vnet]
}

data "azurerm_subnet" "subnet_oracle" {
  count                = local.subnet_oracle_exists ? 0 : 1
  name                 = local.database_subnet_name
  resource_group_name  = var.resource_group.name
  virtual_network_name = data.azurerm_virtual_network.vnet_oracle[count.index].name

  depends_on = [module.vnet]
}
