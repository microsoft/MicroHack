# ===============================================================================
# Provider Configuration
# ===============================================================================
# This file configures the Azure providers with appropriate feature flags
# and authentication settings for the Oracle on Azure infrastructure.
# ===============================================================================

locals {
  aks_subscription_ids         = [for target in var.subscription_targets : target.subscription_id]
  fallback_aks_subscription_id = var.odaa_subscription_id
  aks_subscription_ids_padded = concat(
    local.aks_subscription_ids,
    [for _ in range(max(0, 5 - length(local.aks_subscription_ids))) : local.fallback_aks_subscription_id]
  )

  aks_tenant_ids         = [for target in var.subscription_targets : target.tenant_id]
  fallback_aks_tenant_id = var.odaa_tenant_id
  aks_tenant_ids_padded = concat(
    local.aks_tenant_ids,
    [for _ in range(max(0, 5 - length(local.aks_tenant_ids))) : local.fallback_aks_tenant_id]
  )

  aks_auxiliary_tenant_ids = distinct(local.aks_tenant_ids)
}

# Default provider (used for Entra ID and shared resources)
provider "azurerm" {
  subscription_id = var.odaa_subscription_id
  tenant_id       = var.odaa_tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy               = true
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }

    managed_disk {
      expand_without_downtime = true
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

# Provider aliases for up to five AKS subscriptions (manual module instances)
provider "azurerm" {
  alias                = "aks_deployment_slot_0"
  subscription_id      = local.aks_subscription_ids_padded[0]
  tenant_id            = local.aks_tenant_ids_padded[0]
  client_id            = var.client_id
  client_secret        = var.client_secret
  auxiliary_tenant_ids = [var.odaa_tenant_id]

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy               = true
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }

    managed_disk {
      expand_without_downtime = true
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

provider "azurerm" {
  alias                = "aks_deployment_slot_1"
  subscription_id      = local.aks_subscription_ids_padded[1]
  tenant_id            = local.aks_tenant_ids_padded[1]
  client_id            = var.client_id
  client_secret        = var.client_secret
  auxiliary_tenant_ids = [var.odaa_tenant_id]

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy               = true
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }

    managed_disk {
      expand_without_downtime = true
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

provider "azurerm" {
  alias                = "aks_deployment_slot_2"
  subscription_id      = local.aks_subscription_ids_padded[2]
  tenant_id            = local.aks_tenant_ids_padded[2]
  client_id            = var.client_id
  client_secret        = var.client_secret
  auxiliary_tenant_ids = [var.odaa_tenant_id]

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy               = true
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }

    managed_disk {
      expand_without_downtime = true
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

provider "azurerm" {
  alias                = "aks_deployment_slot_3"
  subscription_id      = local.aks_subscription_ids_padded[3]
  tenant_id            = local.aks_tenant_ids_padded[3]
  client_id            = var.client_id
  client_secret        = var.client_secret
  auxiliary_tenant_ids = [var.odaa_tenant_id]

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy               = true
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }

    managed_disk {
      expand_without_downtime = true
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

provider "azurerm" {
  alias                = "aks_deployment_slot_4"
  subscription_id      = local.aks_subscription_ids_padded[4]
  tenant_id            = local.aks_tenant_ids_padded[4]
  client_id            = var.client_id
  client_secret        = var.client_secret
  auxiliary_tenant_ids = [var.odaa_tenant_id]

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy               = true
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }

    managed_disk {
      expand_without_downtime = true
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

# Provider for ODAA subscription (single subscription for all ODAA VNets)
provider "azurerm" {
  alias                = "odaa"
  subscription_id      = var.odaa_subscription_id
  tenant_id            = var.odaa_tenant_id
  client_id            = var.client_id
  client_secret        = var.client_secret
  auxiliary_tenant_ids = local.aks_auxiliary_tenant_ids

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy               = true
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }

    managed_disk {
      expand_without_downtime = true
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
}

# ===============================================================================
# End of Providers Configuration
# ===============================================================================

# provider "azapi" {
#   # AzAPI provider configuration
#   # This provider is used for Oracle Database on Azure resources
# }

provider "azuread" {
  # AzureAD provider configuration
  # This provider is used for managing Entra ID (Azure Active Directory) resources
  tenant_id     = var.odaa_tenant_id
  client_id     = var.client_id
  client_secret = var.client_secret
}

# AzureAD provider aliases per AKS deployment tenant
provider "azuread" {
  alias         = "aks_deployment_slot_0"
  tenant_id     = local.aks_tenant_ids_padded[0]
  client_id     = var.client_id
  client_secret = var.client_secret
}

provider "azuread" {
  alias         = "aks_deployment_slot_1"
  tenant_id     = local.aks_tenant_ids_padded[1]
  client_id     = var.client_id
  client_secret = var.client_secret
}

provider "azuread" {
  alias         = "aks_deployment_slot_2"
  tenant_id     = local.aks_tenant_ids_padded[2]
  client_id     = var.client_id
  client_secret = var.client_secret
}

provider "azuread" {
  alias         = "aks_deployment_slot_3"
  tenant_id     = local.aks_tenant_ids_padded[3]
  client_id     = var.client_id
  client_secret = var.client_secret
}

provider "azuread" {
  alias         = "aks_deployment_slot_4"
  tenant_id     = local.aks_tenant_ids_padded[4]
  client_id     = var.client_id
  client_secret = var.client_secret
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Get current subscription information
data "azurerm_subscription" "current" {}