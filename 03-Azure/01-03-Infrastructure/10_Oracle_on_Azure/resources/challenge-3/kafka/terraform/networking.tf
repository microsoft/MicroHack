####################################################
# Networking
####################################################

resource "azurerm_virtual_network" "vnet" {
  name                = var.prefix
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = var.prefix
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/21"]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "subnet_aca" {
  name                 = "aca"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.8.0/21"]
  service_endpoints    = ["Microsoft.Storage"]
  # Delegate the subnet to "Microsoft.App/environments" cause of the use of workload profiles
  delegation {
    name = "aca-delegation"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "subnet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.16.0/21"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = var.prefix
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-Port-445"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Port-2049"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2049"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnetaca_nsg" {
  subnet_id                 = azurerm_subnet.subnet_aca.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# module "bastion" {
#   source         = "./modules/bastion-host"
#   resource_group = azurerm_resource_group.rg.name
#   location       = azurerm_resource_group.rg.location
#   name           = var.prefix
#   subnet_id      = azurerm_subnet.subnet_bastion.id
# }

# module "vm" {
#   source             = "./modules/virtual-machine-linux"
#   resource_group     = azurerm_resource_group.rg.name
#   name               = var.prefix
#   subnet_id          = azurerm_subnet.subnet.id
#   location           = azurerm_resource_group.rg.location
#   zone               = "1"
#   vm_size            = "Standard_B2s"
#   username           = var.username
#   password           = var.password
#   use_vm_custom_data = true
#   custom_data        = base64encode("python3 -m http.server")
#   depends_on         = [azurerm_subnet.subnet]
#   admin_principal_id = data.azuread_user.current_user_object_id.object_id
# }