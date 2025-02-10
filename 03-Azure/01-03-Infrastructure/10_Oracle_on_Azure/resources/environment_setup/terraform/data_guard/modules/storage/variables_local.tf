locals {
  data_disks = flatten(
    [
      for disk in var.database_disks_options.data_disks : [
        for i in range(0, disk.count) : {
          name                      = "${var.vm.name}-datadisk${i}"
          caching                   = disk.caching
          create_option             = disk.create_option
          disk_size_gb              = disk.disk_size_gb
          lun                       = disk.lun + i
          managed_disk_type         = disk.disk_type
          storage_account_type      = disk.disk_type
          write_accelerator_enabled = disk.write_accelerator_enabled
        }
      ]
    ]
  )
  asm_disks = flatten(
    [
      for disk in var.database_disks_options.asm_disks : [
        for i in range(0, disk.count) : {
          name                      = "${var.vm.name}-asmdisk${i}"
          caching                   = disk.caching
          create_option             = disk.create_option
          disk_size_gb              = disk.disk_size_gb
          lun                       = disk.lun + i
          managed_disk_type         = disk.disk_type
          storage_account_type      = disk.disk_type
          write_accelerator_enabled = disk.write_accelerator_enabled
        }
      ]
    ]
  )
  redo_disks = flatten(
    [
      for disk in var.database_disks_options.redo_disks : [
        for i in range(0, disk.count) : {
          name                      = "${var.vm.name}-redodisk${i}"
          caching                   = disk.caching
          create_option             = disk.create_option
          disk_size_gb              = disk.disk_size_gb
          lun                       = disk.lun + i
          managed_disk_type         = disk.disk_type
          storage_account_type      = disk.disk_type
          write_accelerator_enabled = disk.write_accelerator_enabled
        }
      ]
    ]
  )
  tags = {}
}
