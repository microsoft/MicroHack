//---------------------------------------------------------Network---------------------------------------------------------//

// Create a virtual network
resource "azurerm_virtual_network" "microhack_vnet" {
  name                = "vnet-microhack"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.microhack_monitoring.location
  resource_group_name = azurerm_resource_group.microhack_monitoring.name
}

// Create subnets
resource "azurerm_subnet" "microhack_subnet" {
  count                 = 2
  name                  = "subnet-microhack-${count.index}"
  address_prefixes      = ["10.0.${count.index}.0/24"]
  virtual_network_name  = azurerm_virtual_network.microhack_vnet.name  
  resource_group_name   = azurerm_resource_group.microhack_monitoring.name
}

// Create NSGs
resource "azurerm_network_security_group" "nsg_subnet_1" {
    name                           = "nsg-subnet-1"
    location                       = azurerm_resource_group.microhack_monitoring.location
    resource_group_name            = azurerm_resource_group.microhack_monitoring.name

    security_rule {
        name                       = "allow-http"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association_subnet_1" {
    subnet_id                 = azurerm_subnet.microhack_subnet[0].id
    network_security_group_id = azurerm_network_security_group.nsg_subnet_1.id
}


resource "azurerm_network_security_group" "nsg_subnet_2" {
    name                           = "nsg-subnet-2"
    location                       = azurerm_resource_group.microhack_monitoring.location
    resource_group_name            = azurerm_resource_group.microhack_monitoring.name

    security_rule {
        name                       = "allow-GatewayManager"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "65200-65534"
        source_address_prefix      = "GatewayManager"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "allow-http"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association_subnet_2" {
    subnet_id                 = azurerm_subnet.microhack_subnet[1].id
    network_security_group_id = azurerm_network_security_group.nsg_subnet_2.id
}