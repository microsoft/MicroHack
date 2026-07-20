resource "azurerm_resource_group" "mh_k8s_onprem" {
  count    = length(local.indices)
  name     = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-onprem"
  location = var.onprem_resources[count.index % length(var.onprem_resources)]
  tags = { "SecurityControl" = "Ignore" }
}

resource "azurerm_resource_group" "mh_k8s_arc" {
  count    = length(local.indices)
  name     = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-arc"
  location = var.arc_location
}

output "rg_names_onprem" {
  #value = azurerm_resource_group.mh_k8s_onprem.name
  value = {
    for i, rg in azurerm_resource_group.mh_k8s_onprem : 
    local.indices[i] => rg.name
  }
}

output "rg_names_arc" {
  #value = azurerm_resource_group.mh_k8s_onprem.name
  value = {
    for i, rg in azurerm_resource_group.mh_k8s_arc :
    local.indices[i] => rg.name
  }
}