# ===============================================================================
# Cloud Shell - Shared Storage Account with Per-User File Shares
# ===============================================================================
# This configuration uses a single existing storage account that all users share,
# with each user getting their own dedicated file share within that storage account.
# ===============================================================================

# ===============================================================================
# Locals for Shared Cloud Shell Storage
# ===============================================================================

locals {
  # Determine which subscription the shared storage is in
  shared_storage_subscription = var.use_shared_cloudshell_storage ? (
    var.shared_cloudshell_subscription_id != null ? var.shared_cloudshell_subscription_id : var.odaa_subscription_id
  ) : null

  # Map of per-user file shares in the shared storage account
  shared_cloudshell_file_shares = var.use_shared_cloudshell_storage ? {
    for key, deployment in local.deployments : key => {
      name                 = "cloudshell-${deployment.name}"
      user_object_id       = module.entra_id_users.user_object_ids[key]
      user_name            = deployment.name
      storage_account_id   = var.shared_cloudshell_storage_account_id
      storage_account_name = var.shared_cloudshell_storage_account_name
      resource_group_name  = var.shared_cloudshell_resource_group_name
    }
  } : {}
}

# ===============================================================================
# Data Source: Reference Existing Shared Storage Account
# ===============================================================================

data "azurerm_storage_account" "shared_cloudshell" {
  count = var.use_shared_cloudshell_storage ? 1 : 0

  provider            = azurerm.cloudshell_storage
  name                = var.shared_cloudshell_storage_account_name
  resource_group_name = var.shared_cloudshell_resource_group_name
}

# ===============================================================================
# File Shares: Per-User File Shares in Shared Storage Account
# ===============================================================================

resource "azurerm_storage_share" "shared_cloudshell" {
  for_each = local.shared_cloudshell_file_shares

  provider           = azurerm.cloudshell_storage
  name               = each.value.name
  storage_account_id = each.value.storage_account_id
  quota              = var.cloudshell_file_share_quota

  depends_on = [data.azurerm_storage_account.shared_cloudshell]
}

# ===============================================================================
# RBAC: Grant Users Storage Blob Data Contributor on Shared Storage Account
# ===============================================================================

resource "azurerm_role_assignment" "shared_cloudshell_storage_blob_contributor" {
  for_each = local.shared_cloudshell_file_shares

  provider             = azurerm.cloudshell_storage
  scope                = each.value.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.user_object_id
  description          = "Grants ${each.value.user_name} permissions to manage Cloud Shell storage blobs in shared storage account"
}

# ===============================================================================
# RBAC: Grant Users Storage File Data SMB Share Contributor
# ===============================================================================

resource "azurerm_role_assignment" "shared_cloudshell_file_contributor" {
  for_each = local.shared_cloudshell_file_shares

  provider             = azurerm.cloudshell_storage
  scope                = each.value.storage_account_id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = each.value.user_object_id
  description          = "Grants ${each.value.user_name} permissions to access their Cloud Shell file share in shared storage account"
}

# ===============================================================================
# RBAC: Grant Users Reader on Storage Resource Group
# ===============================================================================

resource "azurerm_role_assignment" "shared_cloudshell_rg_reader" {
  for_each = local.shared_cloudshell_file_shares

  provider             = azurerm.cloudshell_storage
  scope                = "/subscriptions/${local.shared_storage_subscription}/resourceGroups/${each.value.resource_group_name}"
  role_definition_name = "Reader"
  principal_id         = each.value.user_object_id
  description          = "Grants ${each.value.user_name} read access to Cloud Shell storage resource group"
}

# ===============================================================================
# Outputs
# ===============================================================================

output "shared_cloudshell_storage" {
  description = "Shared Cloud Shell storage account with per-user file shares"
  value = var.use_shared_cloudshell_storage ? {
    storage_account_name = var.shared_cloudshell_storage_account_name
    storage_account_id   = var.shared_cloudshell_storage_account_id
    resource_group_name  = var.shared_cloudshell_resource_group_name
    subscription_id      = local.shared_storage_subscription
    location             = var.use_shared_cloudshell_storage ? data.azurerm_storage_account.shared_cloudshell[0].location : null
    user_file_shares = {
      for key, deployment in local.deployments : deployment.name => {
        file_share_name    = "cloudshell-${deployment.name}"
        file_share_id      = azurerm_storage_share.shared_cloudshell[key].id
        file_share_url     = azurerm_storage_share.shared_cloudshell[key].url
        setup_instructions = "User ${deployment.name} should select storage account '${var.shared_cloudshell_storage_account_name}' and file share 'cloudshell-${deployment.name}' when launching Cloud Shell"
      }
    }
  } : null
}

output "shared_cloudshell_setup_guide" {
  description = "Instructions for users to set up Cloud Shell with shared storage account"
  value = var.use_shared_cloudshell_storage ? {
    message = "All users share the same storage account '${var.shared_cloudshell_storage_account_name}' with individual file shares."
    storage_account_info = {
      name            = var.shared_cloudshell_storage_account_name
      resource_group  = var.shared_cloudshell_resource_group_name
      subscription_id = local.shared_storage_subscription
    }
    setup_steps = [
      "1. Log in to Azure Portal with your user credentials",
      "2. Click the Cloud Shell icon (>_) in the top navigation bar",
      "3. Select 'Bash' or 'PowerShell' environment",
      "4. Choose 'Show advanced settings'",
      "5. Select subscription: ${local.shared_storage_subscription}",
      "6. Select resource group: ${var.shared_cloudshell_resource_group_name}",
      "7. Select storage account: ${var.shared_cloudshell_storage_account_name}",
      "8. Enter YOUR specific file share name: cloudshell-user00, cloudshell-user01, etc.",
      "9. Click 'Attach storage' to complete setup"
    ]
    per_user_file_shares = {
      for key, deployment in local.deployments : deployment.name => "cloudshell-${deployment.name}"
    }
    note = "Each user has their own file share within the shared storage account. Users can only access their own file share due to RBAC permissions."
  } : null
}
