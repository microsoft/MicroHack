#########################################################################################
#                                                                                       #
#  Subscription                                                                         #
#                                                                                       #
#########################################################################################
data "azurerm_subscription" "current" {}

#########################################################################################
#                                                                                       #
#  Resource Group                                                                       #
#                                                                                       #
#########################################################################################
resource "azurerm_resource_group" "rg" {
  count    = local.resource_group_exists ? 0 : 1
  name     = local.rg_name
  location = var.infrastructure.region
  tags     = var.tags

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

data "azurerm_resource_group" "rg" {
  name = local.rg_name

  depends_on = [azurerm_resource_group.rg]
}

#########################################################################################
#                                                                                       #
#  Diagnostic Settings                                                                  #
#                                                                                       #
#########################################################################################
resource "azurerm_storage_account" "diagnostic" {
  count               = var.is_diagnostic_settings_enabled ? 1 : 0
  name                = "${local.prefix}diag${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  tags = merge(local.tags, var.tags)

  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_storage_account" "diagnostic" {
  count               = var.is_diagnostic_settings_enabled ? 1 : 0
  name                = azurerm_storage_account.diagnostic[count.index].name
  resource_group_name = data.azurerm_resource_group.rg.name

  depends_on = [azurerm_storage_account.diagnostic]
}

resource "random_string" "suffix" {
  length  = 14
  special = false
  upper   = false
}

data "azurerm_storage_account_sas" "diagnostic" {
  count             = var.is_diagnostic_settings_enabled ? 1 : 0
  connection_string = azurerm_storage_account.diagnostic[0].primary_connection_string

  resource_types {
    service   = false
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = true
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "8766h")

  permissions {
    read    = false
    write   = true
    delete  = false
    list    = true
    add     = true
    create  = true
    update  = true
    process = false
    tag     = false
    filter  = false
  }
}

resource "azurerm_log_analytics_workspace" "diagnostic" {
  count               = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Log_Analytics_Workspace" ? 1 : 0
  name                = "${local.prefix}diag${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags = merge(local.tags, var.tags)
}

data "azurerm_log_analytics_workspace" "diagnostic" {
  count               = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Log_Analytics_Workspace" ? 1 : 0
  name                = "${local.prefix}diag${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name

  depends_on = [azurerm_log_analytics_workspace.diagnostic]
}

resource "azurerm_eventhub_namespace" "diagnostic" {
  count               = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Event_Hubs" ? 1 : 0
  name                = "${local.prefix}diag${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard"
  capacity            = 1
  tags = merge(local.tags, var.tags)
}

resource "azurerm_eventhub_namespace_authorization_rule" "diagnostic" {
  count               = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Event_Hubs" ? 1 : 0
  name                = "${local.prefix}diag${random_string.suffix.result}"
  namespace_name      = azurerm_eventhub_namespace.diagnostic[0].name
  resource_group_name = data.azurerm_resource_group.rg.name
  listen              = var.eventhub_permission.listen
  send                = var.eventhub_permission.send
  manage              = var.eventhub_permission.manage
}

resource "azurerm_new_relic_monitor" "diagnostic" {
  count               = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Partner_Solutions" ? 1 : 0
  name                = "${local.prefix}diag${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  plan {
    effective_date = "2023-09-20T00:00:00Z"
  }

  user {
    email        = var.logz_user.email
    first_name   = var.logz_user.first_name
    last_name    = var.logz_user.last_name
    phone_number = var.logz_user.phone_number
  }
}
