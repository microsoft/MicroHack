# ===============================================================================
# Cloud Shell - Use Existing Storage Accounts
# ===============================================================================
# This configuration allows you to reference existing storage accounts for
# Cloud Shell instead of creating new ones. Useful when storage accounts are
# already provisioned or managed separately.
# ===============================================================================

# Data source to reference existing storage accounts
data "azurerm_storage_account" "existing_cloudshell" {
  for_each = var.use_existing_cloudshell_storage ? var.existing_cloudshell_storage_accounts : {}

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

# Output existing storage account information
output "existing_cloudshell_storage" {
  description = "Information about existing Cloud Shell storage accounts being used"
  value = var.use_existing_cloudshell_storage ? {
    for key, storage in var.existing_cloudshell_storage_accounts : key => {
      storage_account_name = storage.name
      resource_group_name  = storage.resource_group_name
      storage_account_id   = data.azurerm_storage_account.existing_cloudshell[key].id
      location             = data.azurerm_storage_account.existing_cloudshell[key].location
      note                 = "Using existing storage account - no new resources created"
    }
  } : null
}
