resource "azurerm_availability_set" "oracle_vm" {
  count               = var.availability_zone == null ? 1 : 0
  name                = "as-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name

  platform_fault_domain_count  = 2

}

data "azurerm_availability_set" "oracle_vm" {
  count               = var.availability_zone == null ? 1 : 0
  name                = "as-${count.index}"
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_availability_set.oracle_vm]
}
