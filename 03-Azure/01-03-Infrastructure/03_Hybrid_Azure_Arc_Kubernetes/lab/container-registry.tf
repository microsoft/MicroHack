# will be used in challenge 04-gitops

resource "azurerm_container_registry" "this" {
    count               = length(local.indices)
    name                = "${format("%02d", local.indices[count.index])}${var.acr_name}"
    resource_group_name = azurerm_resource_group.mh_k8s_arc[count.index].name
    location            = azurerm_resource_group.mh_k8s_arc[count.index].location
    sku                 = var.container_registry_sku
    admin_enabled       = var.container_registry_admin_enabled
}

output "acr_names" {
    value = {
        for i, acr in azurerm_container_registry.this :
        local.indices[i] => acr.name
    }
}