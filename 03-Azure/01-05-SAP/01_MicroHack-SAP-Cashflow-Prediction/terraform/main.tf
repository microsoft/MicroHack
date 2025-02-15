terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_id" "id" {
  byte_length = 8
}

#######################################################################
## Create Resource Group
#######################################################################

resource "azurerm_resource_group" "rg" {
  name     = "microhack-${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

#######################################################################
## Assign Storage Role to User
#######################################################################

data "external" "azaccount" {
  program = ["az","ad","signed-in-user","show","--query","{displayName: displayName,objectId: objectId,objectType: objectType}"]
}

data "azurerm_client_config" "user" {
}

locals {
  object_id = data.azurerm_client_config.user.object_id == "" ? data.external.azaccount.result.objectId : data.azurerm_client_config.user.object_id
}

resource "azurerm_role_assignment" "storagerole" {
  scope                 = azurerm_resource_group.rg.id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = local.object_id
}

#######################################################################
## Create Virtual Networks
#######################################################################

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = var.address_space
  tags                = var.tags
}

#######################################################################
## Create Subnet
#######################################################################

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_prefixes
}

#######################################################################
## Create Network Security Group
#######################################################################

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags

  security_rule {
    name                        = "RDP"
    priority                    = 1001
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "3389"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }
}

#######################################################################
## Associate the subnet with the NSG
#######################################################################

resource "azurerm_subnet_network_security_group_association" "nsg-ass" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#######################################################################
## Create Key Vault
#######################################################################

resource "azurerm_key_vault" "keyvault" {
  name                  = "sapkv${lower(random_id.id.hex)}"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  tenant_id             = data.azurerm_client_config.user.tenant_id
  sku_name              = "standard"
  tags                  = var.tags

  access_policy {
    tenant_id = data.azurerm_client_config.user.tenant_id
    object_id = local.object_id

    key_permissions = [
      "Create",
      "Get",
      "Purge",
      "List",
      "Delete"
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover",
      "List"
    ]
  }
}

#######################################################################
## Add secret to Key Vault
#######################################################################

resource "azurerm_key_vault_secret" "secret" {
  name         = var.username
  value        = var.password
  key_vault_id = azurerm_key_vault.keyvault.id
}