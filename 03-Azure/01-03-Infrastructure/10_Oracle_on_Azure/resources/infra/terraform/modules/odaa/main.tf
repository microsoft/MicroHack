# ===============================================================================
# ODAA Module - Main Configuration
# ===============================================================================
# This module creates Oracle Database on Autonomous Azure (ODAA) infrastructure
# including virtual network, subnet with Oracle delegation, and autonomous database.
# ===============================================================================

# ===============================================================================
# Resource Group
# ===============================================================================

resource "azurerm_resource_group" "odaa" {
  name     = "odaa-${var.prefix}${var.postfix}"
  location = var.location
  tags     = var.tags
}

# ===============================================================================
# Virtual Network
# ===============================================================================

resource "azurerm_virtual_network" "odaa" {
  name                = "odaa-${var.prefix}${var.postfix}"
  location            = azurerm_resource_group.odaa.location
  resource_group_name = azurerm_resource_group.odaa.name
  address_space       = ["${var.cidr}/16"]
  tags                = var.tags
}

# ===============================================================================
# Subnet with Oracle Delegation
# ===============================================================================

resource "azurerm_subnet" "odaa" {
  name                 = "odaa-${var.prefix}${var.postfix}"
  resource_group_name  = azurerm_resource_group.odaa.name
  virtual_network_name = azurerm_virtual_network.odaa.name
  address_prefixes     = ["${var.cidr}/24"]

  delegation {
    name = "oracle-delegation"
    service_delegation {
      name = "Oracle.Database/networkAttachments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

# ===============================================================================
# Oracle Autonomous Database
# ===============================================================================
# Note: Oracle Database on Azure requires the azapi provider
# The Oracle.Database resource provider must be registered in your subscription

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }
}

resource "azapi_resource" "autonomous_database" {
  count     = var.create_autonomous_database ? 1 : 0
  type      = "Oracle.Database/autonomousDatabases@2025-03-01"
  name      = "odaa-${var.prefix}${var.postfix}"
  location  = azurerm_resource_group.odaa.location
  parent_id = azurerm_resource_group.odaa.id

  body = jsonencode({
    properties = {
      adminPassword = var.password
      dataBaseType  = "Regular"
      computeCount  = 2
      computeModel  = "ECPU"
      customerContacts = [
        {
          email = "maik.sandmann@gmx.net"
        }
      ]
      dataStorageSizeInGbs           = 20
      databaseEdition                = "EnterpriseEdition"
      dbVersion                      = "23ai"
      dbWorkload                     = "OLTP"
      displayName                    = "${var.prefix}${var.postfix}"
      isAutoScalingEnabled           = false
      isAutoScalingForStorageEnabled = false
      isLocalDataGuardEnabled        = false
      isMtlsConnectionRequired       = false
      licenseModel                   = "BringYourOwnLicense"
      openMode                       = "ReadWrite"
      subnetId                       = azurerm_subnet.odaa.id
      vnetId                         = azurerm_virtual_network.odaa.id
      backupRetentionPeriodInDays    = 1
    }
  })

  tags = var.tags

  depends_on = [
    azurerm_subnet.odaa
  ]
}