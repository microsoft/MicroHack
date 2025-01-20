#########################################################################################
#                                                                                       #
#  Virtual Machine                                                                      #
#                                                                                       #
#########################################################################################


module "avm-res-compute-virtualmachine" {
  source   = "Azure/avm-res-compute-virtualmachine/azurerm"
  version  = "0.17.0"
  for_each = local.vm_config_data_parameter


  name                   = each.value.name
  location               = var.location
  resource_group_name    = var.resource_group_name
  os_type                = each.value.os_type

  generate_admin_password_or_ssh_key = each.value.generate_admin_password_or_ssh_key
  disable_password_authentication    = !each.value.enable_auth_password #!local.enable_auth_password #should be true
  admin_username                     = each.value.admin_username
  admin_ssh_keys                     = [each.value.admin_ssh_keys]
  source_image_reference             = each.value.source_image_reference
  sku_size                           = each.value.virtualmachine_sku_size
  os_disk                            = each.value.os_disk
  extensions                         = var.vm_extensions
  network_interfaces                 = each.value.network_interfaces


  zone                         = each.value.availability_zone
  availability_set_resource_id = var.availability_zone == null ? data.azurerm_availability_set.oracle_vm[0].id : null
  tags                         = merge(local.tags, var.tags)



  managed_identities = {
    system_assigned            = var.aad_system_assigned_identity
  }


  role_assignments = each.value.role_assignments
}



