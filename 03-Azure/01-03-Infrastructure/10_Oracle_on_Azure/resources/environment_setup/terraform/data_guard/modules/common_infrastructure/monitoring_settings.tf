
#Data collection rules
resource "azurerm_monitor_data_collection_rule" "collection_rule_linux" {
  count               = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Log_Analytics_Workspace" ? 1 : 0
  kind                = "Linux"
  location            = var.infrastructure.region
  name                = "LinuxCollectionRule"
  resource_group_name = local.rg_name
  tags                = var.tags
  data_flow {
    destinations  = [data.azurerm_log_analytics_workspace.diagnostic[0].name]
    output_stream = "Microsoft-Perf"
    streams       = ["Microsoft-Perf"]
    transform_kql = "source"
  }
  data_flow {
    destinations  = [data.azurerm_log_analytics_workspace.diagnostic[0].name]
    output_stream = "Microsoft-Syslog"
    streams       = ["Microsoft-Syslog"]
    transform_kql = "source"
  }
  data_sources {
    performance_counter {
      counter_specifiers            = ["Processor(*)\\% Processor Time", "Processor(*)\\% Idle Time", "Processor(*)\\% User Time", "Processor(*)\\% Nice Time", "Processor(*)\\% Privileged Time", "Processor(*)\\% IO Wait Time", "Processor(*)\\% Interrupt Time", "Processor(*)\\% DPC Time", "Memory(*)\\Available MBytes Memory", "Memory(*)\\% Available Memory", "Memory(*)\\Used Memory MBytes", "Memory(*)\\% Used Memory", "Memory(*)\\Pages/sec", "Memory(*)\\Page Reads/sec", "Memory(*)\\Page Writes/sec", "Memory(*)\\Available MBytes Swap", "Memory(*)\\% Available Swap Space", "Memory(*)\\Used MBytes Swap Space", "Memory(*)\\% Used Swap Space", "Process(*)\\Pct User Time", "Process(*)\\Pct Privileged Time", "Process(*)\\Used Memory", "Process(*)\\Virtual Shared Memory", "Logical Disk(*)\\% Free Inodes", "Logical Disk(*)\\% Used Inodes", "Logical Disk(*)\\Free Megabytes", "Logical Disk(*)\\% Free Space", "Logical Disk(*)\\% Used Space", "Logical Disk(*)\\Logical Disk Bytes/sec", "Logical Disk(*)\\Disk Read Bytes/sec", "Logical Disk(*)\\Disk Write Bytes/sec", "Logical Disk(*)\\Disk Transfers/sec", "Logical Disk(*)\\Disk Reads/sec", "Logical Disk(*)\\Disk Writes/sec", "Network(*)\\Total Bytes Transmitted", "Network(*)\\Total Bytes Received", "Network(*)\\Total Bytes", "Network(*)\\Total Packets Transmitted", "Network(*)\\Total Packets Received", "Network(*)\\Total Rx Errors", "Network(*)\\Total Tx Errors", "Network(*)\\Total Collisions", "System(*)\\Uptime", "System(*)\\Load1", "System(*)\\Load5", "System(*)\\Load15", "System(*)\\Users", "System(*)\\Unique Users", "System(*)\\CPUs"]
      name                          = "perfCounterDataSource60"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-Perf"]
    }
    syslog {
      facility_names = ["alert", "audit", "auth", "authpriv", "clock", "cron", "daemon", "ftp", "kern", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7", "lpr", "mail", "news", "nopri", "ntp", "syslog", "user", "uucp"]
      log_levels     = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      name           = "sysLogsDataSource-1688419672"
    }
  }


  destinations {

    dynamic "log_analytics" {
      for_each = local.law_destination_settings
      iterator = dest

      content {
        workspace_resource_id = dest.value.resource_id
        name                  = dest.value.name
      }
    }

    dynamic "event_hub" {
      for_each = local.eventhub_destination_settings

      content {
        event_hub_id = each.value.resource_id
        name         = each.value.name
      }
    }

    dynamic "storage_blob" {
      for_each = local.storage_account_destination_settings

      content {
        storage_account_id = each.value.resource_id
        container_name     = each.value.container_name
        name               = each.value.name
      }
    }
  }


  depends_on = [data.azurerm_log_analytics_workspace.diagnostic]
}

# Data collection rule for VM Insights
resource "azurerm_monitor_data_collection_rule" "collection_rule_vm_insights" {
  count               = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Log_Analytics_Workspace" ? 1 : 0
  description         = "Data collection rule for VM Insights."
  location            = var.infrastructure.region
  name                = "MSVMI-DataCollectionRuleVMInsights"
  resource_group_name = local.rg_name
  tags                = var.tags

  data_flow {
    destinations = ["VMInsightsPerf-Logs-Dest"]
    streams      = ["Microsoft-InsightsMetrics"]
  }
  data_flow {
    destinations = ["VMInsightsPerf-Logs-Dest"]
    streams      = ["Microsoft-ServiceMap"]
  }
  data_sources {
    extension {
      extension_name = "DependencyAgent"
      name           = "DependencyAgentDataSource"
      streams        = ["Microsoft-ServiceMap"]
    }
    performance_counter {
      counter_specifiers            = ["\\VmInsights\\DetailedMetrics"]
      name                          = "VMInsightsPerfCounters"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-InsightsMetrics"]
    }
  }
  destinations {
    log_analytics {
      name                  = "VMInsightsPerf-Logs-Dest"
      workspace_resource_id = data.azurerm_log_analytics_workspace.diagnostic[0].id
    }
  }
  depends_on = [
    data.azurerm_log_analytics_workspace.diagnostic
  ]
}

data "azurerm_monitor_data_collection_rule" "collection_rule_linux" {
  count = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Log_Analytics_Workspace" ? 1 : 0

  name                = azurerm_monitor_data_collection_rule.collection_rule_linux[0].name
  resource_group_name = local.rg_name
}


data "azurerm_monitor_data_collection_rule" "collection_rule_vm_insights" {
  count = var.is_diagnostic_settings_enabled && var.diagnostic_target == "Log_Analytics_Workspace" ? 1 : 0

  name                = azurerm_monitor_data_collection_rule.collection_rule_vm_insights[0].name
  resource_group_name = local.rg_name
}
