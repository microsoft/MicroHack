output "data_disks" {
  value = local.data_disks
}

output "asm_disks" {
  value = local.asm_disks
}

output "redo_disks" {
  value = local.redo_disks
}


output "data_disks_resource" {
  value = data.azurerm_managed_disk.data_disk
}

output "asm_disks_resource" {
  value = data.azurerm_managed_disk.asm_disk
}

output "redo_disks_resource" {
  value = data.azurerm_managed_disk.redo_disk
}