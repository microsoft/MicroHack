resource "azurerm_managed_disk" "data_disk" {
  count                = length(local.data_disks)
  name                 = "${var.naming}-data-${count.index}"
  location             = var.resource_group.location
  resource_group_name  = var.resource_group.name
  storage_account_type = var.disk_type
  create_option        = local.data_disks[count.index].create_option
  disk_size_gb         = local.data_disks[count.index].disk_size_gb
  zone                 = var.availability_zone

  tags = merge(local.tags, var.tags)
}

resource "azurerm_managed_disk" "asm_disk" {
  count                = length(local.asm_disks)
  name                 = "${var.naming}-asm-${count.index}"
  location             = var.resource_group.location
  resource_group_name  = var.resource_group.name
  storage_account_type = var.disk_type
  create_option        = local.asm_disks[count.index].create_option
  disk_size_gb         = local.asm_disks[count.index].disk_size_gb
  zone                 = var.availability_zone

  tags = merge(local.tags, var.tags)
}

resource "azurerm_managed_disk" "redo_disk" {
  count                = length(local.redo_disks)
  name                 = "${var.naming}-redo-${count.index}"
  location             = var.resource_group.location
  resource_group_name  = var.resource_group.name
  storage_account_type = var.disk_type
  create_option        = local.redo_disks[count.index].create_option
  disk_size_gb         = local.redo_disks[count.index].disk_size_gb
  zone                 = var.availability_zone

  tags = merge(local.tags, var.tags)
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  count                     = length(local.data_disks)
  managed_disk_id           = azurerm_managed_disk.data_disk[count.index].id
  virtual_machine_id        = var.vm.id
  caching                   = local.data_disks[count.index].caching
  write_accelerator_enabled = local.data_disks[count.index].write_accelerator_enabled
  lun                       = local.data_disks[count.index].lun
}

resource "azurerm_virtual_machine_data_disk_attachment" "asm_disk_attachment" {
  count                     = length(local.asm_disks)
  managed_disk_id           = azurerm_managed_disk.asm_disk[count.index].id
  virtual_machine_id        = var.vm.id
  caching                   = local.asm_disks[count.index].caching
  write_accelerator_enabled = local.asm_disks[count.index].write_accelerator_enabled
  lun                       = local.asm_disks[count.index].lun
}

resource "azurerm_virtual_machine_data_disk_attachment" "redo_disk_attachment" {
  count                     = length(local.redo_disks)
  managed_disk_id           = azurerm_managed_disk.redo_disk[count.index].id
  virtual_machine_id        = var.vm.id
  caching                   = local.redo_disks[count.index].caching
  write_accelerator_enabled = local.redo_disks[count.index].write_accelerator_enabled
  lun                       = local.redo_disks[count.index].lun
}

data "azurerm_managed_disk" "data_disk" {
  count               = length(local.data_disks)
  name                = azurerm_managed_disk.data_disk[count.index].name
  resource_group_name = var.resource_group.name
}

data "azurerm_managed_disk" "asm_disk" {
  count               = length(local.asm_disks)
  name                = azurerm_managed_disk.asm_disk[count.index].name
  resource_group_name = var.resource_group.name
}

data "azurerm_managed_disk" "redo_disk" {
  count               = length(local.redo_disks)
  name                = azurerm_managed_disk.redo_disk[count.index].name
  resource_group_name = var.resource_group.name
}
