output "vm" {
  value = data.azurerm_virtual_machine.oracle_vm_primary
}

output "database_server_count" {
  value = var.database_server_count
}

output "availability_zone" {
  value = var.availability_zone != null ? var.availability_zone : null
}

output "oracle_vms" {
  value     = data.azurerm_virtual_machine.oracle_vms
  sensitive = true
}

output "vm_map_collection" {
  value = { for vm in module.avm-res-compute-virtualmachine : vm.name => {
    name       = vm.name
    id         = vm.resource_id
    public_ips = vm.public_ips

  } }
  sensitive = false
}


output "vm_collection" {
  value     = flatten([for vm in module.avm-res-compute-virtualmachine : vm.name])
  sensitive = false
}
