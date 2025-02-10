# Create Data Collection Rule Association for VM created
resource "azurerm_monitor_data_collection_rule_association" "dcra_vm_insights" {
  # Create association for each data collection rule
  for_each = { for key, val in var.data_collection_rules : key => val if(var.log_analytics_workspace != null && var.is_diagnostic_settings_enabled) }

  name                    = each.key
  target_resource_id      = data.azurerm_virtual_machine.oracle_vm_primary.id
  data_collection_rule_id = each.value.id
}

