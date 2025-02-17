resource azurerm_resource_group "storage_rg" {
  name     = var.storage_rg_name
  location = var.location
}

resource azurerm_storage_account "storage_account" {
  name                      = var.sa_name
  resource_group_name       = azurerm_resource_group.storage_rg.name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  shared_access_key_enabled = false

}

resource "azurerm_user_assigned_identity" "mid" {
  location            = azurerm_resource_group.storage_rg.location
  resource_group_name = azurerm_resource_group.storage_rg.name
  name                = var.user_managed_identity
}

# assign data contributor role on storage account to mid
resource "azurerm_role_assignment" "rbac_mid" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.mid.principal_id
} 

# assign data contributor role on storage account to interactive user
resource "azurerm_role_assignment" "rbac_current_user" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
} 

# create a container to store the Oracle installation binaries
resource azurerm_storage_container "container" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "private"
  depends_on            = [azurerm_role_assignment.rbac_current_user]
}

output "container_url" {
  value = azurerm_storage_account.storage_account.primary_blob_endpoint
}
