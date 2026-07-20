
resource "azurerm_log_analytics_workspace" "law" {
    count               = length(local.indices)
    name                = "${format("%02d", local.indices[count.index])}-law"

    resource_group_name = azurerm_resource_group.mh_k8s_arc[count.index].name
    location            = azurerm_resource_group.mh_k8s_arc[count.index].location
    
    sku                 = "PerGB2018"
    retention_in_days   = 30
}

output "law" {
  value = {
    for i, item in azurerm_log_analytics_workspace.law : 
    local.indices[i] => item.id
  }
}