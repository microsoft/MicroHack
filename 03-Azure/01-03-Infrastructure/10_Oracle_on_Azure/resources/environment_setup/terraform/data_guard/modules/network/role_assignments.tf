data "azurerm_client_config" "current" {}

# data "azurerm_role_definition" "nic" {
#   for_each = var.role_assignments_nic
#   name     = each.value.name
# }

data "azurerm_role_definition" "pip" {
  for_each = var.role_assignments_pip
  name     = each.value.name
}

data "azurerm_role_definition" "nsg" {
  for_each = var.role_assignments_nsg
  name     = each.value.name
}

data "azurerm_role_definition" "vnet" {
  for_each = var.role_assignments_vnet
  name     = each.value.name
}

data "azurerm_role_definition" "subnet" {
  for_each = var.role_assignments_subnet
  name     = each.value.name
}


# resource "azurerm_role_assignment" "nic" {
#   for_each                         = var.role_assignments_nic
#   role_definition_name             = data.azurerm_role_definition.nic[each.key].name
#   principal_id                     = data.azurerm_client_config.current.object_id
#   scope                            = try(each.value.scope, data.azurerm_network_interface.oracle_db[0].id)
#   skip_service_principal_aad_check = try(each.value.skip_service_principal_aad_check, false)
#   description                      = try(each.value.description, null)
#   condition                        = try(each.value.condition, null)
#   condition_version                = try(each.value.condition_version, null)
# }

resource "azurerm_role_assignment" "pip" {
  for_each                         = var.role_assignments_pip
  role_definition_name             = data.azurerm_role_definition.pip[each.key].name
  principal_id                     = data.azurerm_client_config.current.object_id
  scope                            = try(each.value.scope, data.azurerm_public_ip.vm_pip[0].id)
  skip_service_principal_aad_check = try(each.value.skip_service_principal_aad_check, false)
  description                      = try(each.value.description, null)
  condition                        = try(each.value.condition, null)
  condition_version                = try(each.value.condition_version, null)
}

resource "azurerm_role_assignment" "nsg" {
  for_each                         = var.role_assignments_nsg
  role_definition_name             = data.azurerm_role_definition.nsg[each.key].name
  principal_id                     = data.azurerm_client_config.current.object_id
  scope                            = try(each.value.scope, data.azurerm_network_security_group.blank.id)
  skip_service_principal_aad_check = try(each.value.skip_service_principal_aad_check, false)
  description                      = try(each.value.description, null)
  condition                        = try(each.value.condition, null)
  condition_version                = try(each.value.condition_version, null)
}

resource "azurerm_role_assignment" "vnet" {
  for_each                         = var.role_assignments_vnet
  role_definition_name             = data.azurerm_role_definition.vnet[each.key].name
  principal_id                     = data.azurerm_client_config.current.object_id
  scope                            = try(each.value.scope, data.azurerm_virtual_network.vnet_oracle[0].id)
  skip_service_principal_aad_check = try(each.value.skip_service_principal_aad_check, false)
  description                      = try(each.value.description, null)
  condition                        = try(each.value.condition, null)
  condition_version                = try(each.value.condition_version, null)
}

resource "azurerm_role_assignment" "subnet" {
  for_each                         = var.role_assignments_subnet
  role_definition_name             = data.azurerm_role_definition.subnet[each.key].name
  principal_id                     = data.azurerm_client_config.current.object_id
  scope                            = try(each.value.scope, data.azurerm_subnet.subnet_oracle[0].id)
  skip_service_principal_aad_check = try(each.value.skip_service_principal_aad_check, false)
  description                      = try(each.value.description, null)
  condition                        = try(each.value.condition, null)
  condition_version                = try(each.value.condition_version, null)
}
