
#ToDo: Should be replicated on VM Module
# resource "azurerm_monitor_diagnostic_setting" "nic" {
#   count                          = var.is_diagnostic_settings_enabled ? 1 : 0
#   name                           = "nic-${count.index}-diag"
#   target_resource_id             = azurerm_network_interface.oracle_db[count.index].id
#   storage_account_id             = var.diagnostic_target == "Storage_Account" ? var.storage_account_id : null
#   log_analytics_workspace_id     = var.diagnostic_target == "Log_Analytics_Workspace" ? var.log_analytics_workspace_id : null
#   eventhub_authorization_rule_id = var.diagnostic_target == "Event_Hubs" ? var.eventhub_authorization_rule_id : null
#   partner_solution_id            = var.diagnostic_target == "Partner_Solutions" ? var.partner_solution_id : null

#   metric {
#     category = "AllMetrics"
#     retention_policy {
#       enabled = false
#     }
#   }
# }

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  count                          = var.is_diagnostic_settings_enabled ? 1 : 0
  name                           = "nsg"
  target_resource_id             = azurerm_network_security_group.blank.id
  storage_account_id             = var.diagnostic_target == "Storage_Account" ? var.storage_account_id : null
  log_analytics_workspace_id     = var.diagnostic_target == "Log_Analytics_Workspace" ? var.log_analytics_workspace_id : null
  eventhub_authorization_rule_id = var.diagnostic_target == "Event_Hubs" ? var.eventhub_authorization_rule_id : null
  partner_solution_id            = var.diagnostic_target == "Partner_Solutions" ? var.partner_solution_id : null

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.nsg[count.index].log_category_types)
    content {
      category = enabled_log.value
      retention_policy {
        enabled = false
      }
    }
  }
}

#ToDo: It does not work
# resource "azurerm_monitor_diagnostic_setting" "pip" {
#   count                          = var.is_diagnostic_settings_enabled ? var.is_data_guard ? 2 : 1 : 0
#   name                           = "pip"
#   target_resource_id             = azurerm_public_ip.vm_pip[count.index].id
#   storage_account_id             = var.diagnostic_target == "Storage_Account" ? var.storage_account_id : null
#   log_analytics_workspace_id     = var.diagnostic_target == "Log_Analytics_Workspace" ? var.log_analytics_workspace_id : null
#   eventhub_authorization_rule_id = var.diagnostic_target == "Event_Hubs" ? var.eventhub_authorization_rule_id : null
#   partner_solution_id            = var.diagnostic_target == "Partner_Solutions" ? var.partner_solution_id : null

#   dynamic "enabled_log" {
#     for_each = toset(data.azurerm_monitor_diagnostic_categories.pip[count.index].log_category_types)
#     content {
#       category = enabled_log.value
#       retention_policy {
#         enabled = false
#       }
#     }
#   }

#   metric {
#     category = "AllMetrics"
#     retention_policy {
#       enabled = false
#     }
#   }
# }

resource "azurerm_monitor_diagnostic_setting" "vnet" {
  count                          = var.is_diagnostic_settings_enabled ? 1 : 0
  name                           = "vnet"
  target_resource_id             = data.azurerm_virtual_network.vnet_oracle[count.index].id
  storage_account_id             = var.diagnostic_target == "Storage_Account" ? var.storage_account_id : null
  log_analytics_workspace_id     = var.diagnostic_target == "Log_Analytics_Workspace" ? var.log_analytics_workspace_id : null
  eventhub_authorization_rule_id = var.diagnostic_target == "Event_Hubs" ? var.eventhub_authorization_rule_id : null
  partner_solution_id            = var.diagnostic_target == "Partner_Solutions" ? var.partner_solution_id : null

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.vnet[count.index].log_category_types)
    content {
      category = enabled_log.value
      retention_policy {
        enabled = false
      }
    }
  }

  metric {
    category = "AllMetrics"
    retention_policy {
      enabled = false
    }
  }
}

# data "azurerm_monitor_diagnostic_categories" "nic" {
#   count       = var.is_diagnostic_settings_enabled ? 1 : 0
#   resource_id = data.azurerm_network_interface.nic[count.index].id
# }

data "azurerm_monitor_diagnostic_categories" "nsg" {
  count       = var.is_diagnostic_settings_enabled ? 1 : 0
  resource_id = data.azurerm_network_security_group.nsg[count.index].id
}

data "azurerm_monitor_diagnostic_categories" "pip" {
  count       = var.is_diagnostic_settings_enabled ? 1 : 0
  resource_id = data.azurerm_public_ip.pip[count.index].id
}

data "azurerm_monitor_diagnostic_categories" "vnet" {
  count       = var.is_diagnostic_settings_enabled ? 1 : 0
  resource_id = data.azurerm_virtual_network.vnet[count.index].id
}

# data "azurerm_network_interface" "nic" {
#   count               = var.is_data_guard ? 2 : 1
#   name                = "oraclevmnic-${count.index}"
#   resource_group_name = var.resource_group.name

#   depends_on = [azurerm_network_interface.oracle_db]
# }

data "azurerm_network_security_group" "nsg" {
  count               = 1
  name                = "blank"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_network_security_group.blank]
}

data "azurerm_public_ip" "pip" {
  count               = var.is_data_guard ? 2 : 1
  name                = "vmpip-${count.index}"
  resource_group_name = var.resource_group.name

  depends_on = [azurerm_public_ip.vm_pip]
}

data "azurerm_virtual_network" "vnet" {
  count               = 1
  name                = local.vnet_oracle_name
  resource_group_name = var.resource_group.name

  depends_on = [module.vnet]
}