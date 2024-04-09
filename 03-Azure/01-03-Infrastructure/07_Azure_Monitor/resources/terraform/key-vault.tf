data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg_kv" {
    name     = "rg-general-resources"
    location = local.kv_location
}

resource "azurerm_key_vault" "mh_kv" {
  name                        = "kv-microhack-monitoring"
  location                    = azurerm_resource_group.rg_kv.location
  resource_group_name         = azurerm_resource_group.rg_kv.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true

  sku_name = "standard"
}