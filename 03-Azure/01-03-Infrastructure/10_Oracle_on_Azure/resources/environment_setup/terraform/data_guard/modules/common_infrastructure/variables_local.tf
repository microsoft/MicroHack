locals {
  resource_group_exists = length(try(var.infrastructure.resource_group.arm_id, "")) > 0
  // If resource ID is specified extract the resourcegroup name from it otherwise read it either from input of create using the naming convention
  rg_name = local.resource_group_exists ? (
    try(split("/", var.infrastructure.resource_group.arm_id))[4]) : (
    length(var.infrastructure.resource_group.name) > 0 ? (
      var.infrastructure.resource_group.name) : (
      format("%s-%s-%s-%s-%s",
        "rg",
        local.prefix,
        "demo",
        var.infrastructure.region,
        "001"
      )
    )
  )

  // Resource group
  prefix = "oracle"


  law_destination_settings = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Log_Analytics_Workspace" ? { Log_Analytics_Workspace = {
    type        = "Log_Analytics_Workspace"
    resource_id = data.azurerm_log_analytics_workspace.diagnostic[0].id
    name        = data.azurerm_log_analytics_workspace.diagnostic[0].name
  } } : {}

  storage_account_destination_settings = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Storage_Account" ? { Storage_Account = {
    type           = "Storage_Account"
    resource_id    = data.azurerm_storage_account.diagnostic[0].id
    container_name = data.azurerm_storage_account_sas.diagnostic[0].sas
    name           = data.azurerm_storage_account.diagnostic[0].name
  } } : {}

  eventhub_destination_settings = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Event_Hubs" ? { Event_Hubs = {
    type        = "Event_Hubs"
    resource_id = azurerm_eventhub_namespace_authorization_rule.diagnostic[0].id
    name        = azurerm_eventhub_namespace_authorization_rule.diagnostic[0].name
  } } : {}


  tags = {}
}
