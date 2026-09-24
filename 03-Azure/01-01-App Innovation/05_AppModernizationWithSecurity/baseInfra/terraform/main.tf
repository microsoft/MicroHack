data "azurerm_client_config" "current" {}

locals {
  user_indices      = range(1, var.n + 1)
  region_count      = length(var.locations)
  user_location_map = { for i in local.user_indices : i => var.locations[(i - 1) % local.region_count] }
  deployment_footprint = {
    virtual_machines = var.n * 2
    regional_vcpus   = var.n * 2 * var.vm_vcpus
    os_disks         = var.n * 2
    os_disk_gib      = var.n * 2 * var.os_disk_size_gb
  }
}

module "resource_providers" {
  source = "./modules/resource_provider_registration"
  count  = var.manage_sub_providers ? 1 : 0
}

module "entra_users" {
  source   = "./modules/entra_user"
  for_each = var.manage_entra_users ? { for i in local.user_indices : i => i } : {}

  user_index      = each.value
  domain          = var.entra_user_domain
  password_length = var.entra_user_password_length
}

module "user_environment" {
  source   = "./modules/user_environment"
  for_each = var.manage_azure_resources ? { for i in local.user_indices : i => i } : {}

  user_index                      = each.value
  subscription_id                 = data.azurerm_client_config.current.subscription_id
  location                        = local.user_location_map[each.value]
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  vm_size                         = var.vm_size
  os_disk_size_gb                 = var.os_disk_size_gb
  source_commit                   = var.source_commit
  source_archive_sha256           = var.source_archive_sha256
  capacity_preflight_confirmed    = var.capacity_preflight_confirmed
  facilitator_principal_name      = var.facilitator_principal_name
  facilitator_principal_object_id = var.facilitator_principal_object_id
  assigned_user_object_id         = var.manage_entra_users ? lookup(module.entra_users, tostring(each.value)).object_id : null
  create_role_assignment          = var.manage_entra_users
  rdp_source_address_prefixes     = var.rdp_source_address_prefixes

  depends_on = [module.resource_providers]
}
