data "azurerm_virtual_machine" "oracle_vm_primary" {
  name                = module.avm-res-compute-virtualmachine[keys(local.vm_config_data_parameter)[0]].virtual_machine.name
  resource_group_name = var.resource_group_name

  depends_on = [module.avm-res-compute-virtualmachine]
}

data "azurerm_virtual_machine" "oracle_vms" {
  for_each            = { for vm in module.avm-res-compute-virtualmachine : vm.name => vm.virtual_machine }
  name                = each.value.name
  resource_group_name = var.resource_group_name

  depends_on = [module.avm-res-compute-virtualmachine]
}
