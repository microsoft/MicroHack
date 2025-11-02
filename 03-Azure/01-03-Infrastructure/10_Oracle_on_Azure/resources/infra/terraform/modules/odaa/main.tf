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

  # Prevent deletion while Oracle databases might be using this subnet
  lifecycle {
    create_before_destroy = true
  }
}

# ===============================================================================
# Oracle Autonomous Database
# ===============================================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  raw_autonomous_database_name = lower("odaa${var.prefix}${var.postfix}")
  # Oracle Autonomous DB name must be alphanumeric; strip common separators.
  autonomous_database_name = replace(
    replace(
      replace(
        replace(local.raw_autonomous_database_name, "-", ""),
      "_", ""),
    ".", ""),
  " ", "")
}

resource "azurerm_oracle_autonomous_database" "autonomous" {
  count = var.create_autonomous_database ? 1 : 0

  name                = local.autonomous_database_name
  resource_group_name = azurerm_resource_group.odaa.name
  location            = azurerm_resource_group.odaa.location
  display_name        = local.autonomous_database_name

  admin_password                   = var.password
  allowed_ips                      = []
  auto_scaling_enabled             = false
  auto_scaling_for_storage_enabled = false
  backup_retention_period_in_days  = 1
  character_set                    = "AL32UTF8"
  compute_count                    = 2
  compute_model                    = "ECPU"
  customer_contacts                = ["maik.sandmann@gmx.net"]
  data_storage_size_in_tbs         = 1
  db_version                       = "23ai"
  db_workload                      = "OLTP"
  license_model                    = "BringYourOwnLicense"
  mtls_connection_required         = false
  national_character_set           = "AL16UTF16"
  subnet_id                        = azurerm_subnet.odaa.id
  virtual_network_id               = azurerm_virtual_network.odaa.id

  tags = var.tags

  depends_on = [
    azurerm_subnet.odaa
  ]
}