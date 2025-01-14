data "azurerm_client_config" "current" {}

data "azurerm_role_definition" "builtin" {
  for_each = var.role_assignments
  name     = each.value.name
}

resource "azurerm_role_assignment" "assignment" {
  for_each                         = var.role_assignments
  role_definition_name             = data.azurerm_role_definition.builtin[each.key].name
  principal_id                     = data.azurerm_client_config.current.object_id
  scope                            = try(each.value.scope, data.azurerm_subscription.current.id)
  skip_service_principal_aad_check = try(each.value.skip_service_principal_aad_check, null)
  description                      = try(each.value.description, null)
  condition                        = try(each.value.condition, null)
  condition_version                = try(each.value.condition_version, null)
}
