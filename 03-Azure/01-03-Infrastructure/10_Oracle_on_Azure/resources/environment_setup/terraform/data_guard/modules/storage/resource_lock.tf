resource "azurerm_management_lock" "data_disk" {
  count      = length(var.data_disk_locks) > 1 && length(try(var.data_disk_locks.name, "")) > 1 ? 1 : 0
  name       = var.data_disk_locks.name
  scope      = data.azurerm_managed_disk.data_disk[0].id
  lock_level = var.data_disk_locks.type

  depends_on = [azurerm_managed_disk.data_disk]
}
