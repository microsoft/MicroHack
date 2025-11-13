# ===============================================================================
# Azure Cloud Shell Storage Accounts for Per-User Environments
# ===============================================================================
# This configuration provisions storage accounts that users can select when
# they first launch Azure Cloud Shell. Each user gets their own storage account
# with a file share pre-configured for Cloud Shell.
#
# Note: Cloud Shell itself cannot be fully automated - users must perform the
# first-time setup in the portal/CLI, but they can select these pre-created
# storage accounts during that process.
# ===============================================================================

# ===============================================================================
# Locals for Cloud Shell Storage
# ===============================================================================

locals {
  # Generate unique storage account names (max 24 chars: prefix(11) + event(8) + postfix(2) + random(3))
  cloudshell_storage_accounts = var.create_cloudshell_storage ? {
    for key, deployment in local.deployments : key => {
      name                = lower(substr(replace("${var.cloudshell_storage_account_prefix}${var.microhack_event_name}${deployment.postfix}${random_string.cloudshell_suffix[key].result}", "/[^a-z0-9]/", ""), 0, 24))
      resource_group_name = "rg-cloudshell-${deployment.name}"
      location            = deployment.location
      user_object_id      = module.entra_id_users.user_object_ids[key]
      user_name           = deployment.name
    }
  } : {}
}

# ===============================================================================
# Random Suffix for Storage Account Names (ensures global uniqueness)
# ===============================================================================

resource "random_string" "cloudshell_suffix" {
  for_each = var.create_cloudshell_storage ? local.deployments : {}

  length  = 3
  special = false
  upper   = false
}

# ===============================================================================
# Resource Groups for Cloud Shell Storage
# ===============================================================================

resource "azurerm_resource_group" "cloudshell" {
  for_each = local.cloudshell_storage_accounts

  name     = each.value.resource_group_name
  location = each.value.location

  tags = merge(local.common_tags, {
    Purpose = "CloudShell Storage"
    User    = each.value.user_name
  })
}

# ===============================================================================
# Storage Accounts for Cloud Shell
# ===============================================================================

resource "azurerm_storage_account" "cloudshell" {
  for_each = local.cloudshell_storage_accounts

  name                     = each.value.name
  resource_group_name      = azurerm_resource_group.cloudshell[each.key].name
  location                 = each.value.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Enable for better security
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  # Disable public access by default
  public_network_access_enabled = true # Must be true for Cloud Shell access

  tags = merge(local.common_tags, {
    Purpose = "CloudShell"
    User    = each.value.user_name
  })

  lifecycle {
    ignore_changes = [
      # Cloud Shell may modify these
      blob_properties,
      network_rules
    ]
  }
}

# ===============================================================================
# File Shares for Cloud Shell
# ===============================================================================

resource "azurerm_storage_share" "cloudshell" {
  for_each = local.cloudshell_storage_accounts

  name               = "cloudshell-${each.value.user_name}"
  storage_account_id = azurerm_storage_account.cloudshell[each.key].id
  quota              = var.cloudshell_file_share_quota

  depends_on = [azurerm_storage_account.cloudshell]
}

# ===============================================================================
# RBAC: Grant Users Storage Blob Data Contributor on Their Storage Account
# ===============================================================================

resource "azurerm_role_assignment" "cloudshell_storage_contributor" {
  for_each = local.cloudshell_storage_accounts

  scope                = azurerm_storage_account.cloudshell[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.user_object_id
  description          = "Grants ${each.value.user_name} permissions to manage Cloud Shell storage blobs"
}

# ===============================================================================
# RBAC: Grant Users Storage File Data SMB Share Contributor
# ===============================================================================

resource "azurerm_role_assignment" "cloudshell_file_contributor" {
  for_each = local.cloudshell_storage_accounts

  scope                = azurerm_storage_account.cloudshell[each.key].id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = each.value.user_object_id
  description          = "Grants ${each.value.user_name} permissions to access Cloud Shell file share"
}

# ===============================================================================
# RBAC: Grant Users Contributor on Cloud Shell Resource Group
# ===============================================================================

resource "azurerm_role_assignment" "cloudshell_rg_contributor" {
  for_each = local.cloudshell_storage_accounts

  scope                = azurerm_resource_group.cloudshell[each.key].id
  role_definition_name = "Contributor"
  principal_id         = each.value.user_object_id
  description          = "Grants ${each.value.user_name} full access to their Cloud Shell resource group"
}

# ===============================================================================
# Outputs
# ===============================================================================

output "cloudshell_storage" {
  description = "Cloud Shell storage account information for each user"
  value = {
    for key, deployment in local.deployments : deployment.name => (
      var.create_cloudshell_storage ? {
        storage_account_name = azurerm_storage_account.cloudshell[key].name
        storage_account_id   = azurerm_storage_account.cloudshell[key].id
        resource_group_name  = azurerm_resource_group.cloudshell[key].name
        file_share_name      = azurerm_storage_share.cloudshell[key].name
        location             = azurerm_storage_account.cloudshell[key].location
        primary_access_key   = azurerm_storage_account.cloudshell[key].primary_access_key
        connection_string    = azurerm_storage_account.cloudshell[key].primary_connection_string
        setup_instructions   = "User ${deployment.name} should select storage account '${azurerm_storage_account.cloudshell[key].name}' and file share '${azurerm_storage_share.cloudshell[key].name}' when first launching Cloud Shell"
      } : null
    )
  }
  sensitive = true
}

output "cloudshell_setup_guide" {
  description = "Instructions for users to set up Cloud Shell with pre-provisioned storage"
  value = var.create_cloudshell_storage ? {
    message = "Cloud Shell storage accounts have been pre-provisioned for each user."
    steps = [
      "1. Log in to Azure Portal with your user credentials",
      "2. Click the Cloud Shell icon (>_) in the top navigation bar",
      "3. Select 'Bash' or 'PowerShell' environment",
      "4. Choose 'Show advanced settings'",
      "5. Select 'Use existing' for both resource group and storage account",
      "6. Select your pre-created resource group and storage account from the dropdown",
      "7. Enter the pre-created file share name shown in the terraform output",
      "8. Click 'Attach storage' to complete setup"
    ]
    note = "Each user should use the storage account and file share created specifically for them. Check the 'cloudshell_storage' output for details."
  } : null
}
