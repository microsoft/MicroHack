# ===============================================================================
# Provider Configuration
# ===============================================================================
# This file configures the Azure providers with appropriate feature flags
# and authentication settings for the Oracle on Azure infrastructure.
# ===============================================================================

locals {
  aks_subscription_ids         = [for deployment in var.aks_deployments : deployment.subscription_id]
  fallback_aks_subscription_id = var.odaa_subscription_id
  aks_subscription_ids_padded = concat(
    local.aks_subscription_ids,
    [for _ in range(max(0, 5 - length(local.aks_subscription_ids))) : local.fallback_aks_subscription_id]
  )

  aks_tenant_ids         = [for deployment in var.aks_deployments : deployment.tenant_id]
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
  alias                = "aks_deployment_team_0"
  subscription_id      = local.aks_subscription_ids_padded[0]
  tenant_id            = local.aks_tenant_ids_padded[0]
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
  alias                = "aks_deployment_team_1"
  subscription_id      = local.aks_subscription_ids_padded[1]
  tenant_id            = local.aks_tenant_ids_padded[1]
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
  alias                = "aks_deployment_team_2"
  subscription_id      = local.aks_subscription_ids_padded[2]
  tenant_id            = local.aks_tenant_ids_padded[2]
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
  alias                = "aks_deployment_team_3"
  subscription_id      = local.aks_subscription_ids_padded[3]
  tenant_id            = local.aks_tenant_ids_padded[3]
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
  alias                = "aks_deployment_team_4"
  subscription_id      = local.aks_subscription_ids_padded[4]
  tenant_id            = local.aks_tenant_ids_padded[4]
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

provider "azapi" {
  # AzAPI provider configuration
  # This provider is used for Oracle Database on Azure resources
}

provider "azuread" {
  # AzureAD provider configuration
  # This provider is used for managing Entra ID (Azure Active Directory) resources
}

# AzureAD provider aliases per AKS deployment tenant
provider "azuread" {
  alias     = "aks_deployment_team_0"
  tenant_id = local.aks_tenant_ids_padded[0]
}

provider "azuread" {
  alias     = "aks_deployment_team_1"
  tenant_id = local.aks_tenant_ids_padded[1]
}

provider "azuread" {
  alias     = "aks_deployment_team_2"
  tenant_id = local.aks_tenant_ids_padded[2]
}

provider "azuread" {
  alias     = "aks_deployment_team_3"
  tenant_id = local.aks_tenant_ids_padded[3]
}

provider "azuread" {
  alias     = "aks_deployment_team_4"
  tenant_id = local.aks_tenant_ids_padded[4]
}

# Kubernetes and Helm provider configurations per AKS deployment
locals {
  aks_team_0_kube_config = length(module.aks_team_0) > 0 ? values(module.aks_team_0)[0].aks_cluster_kube_config[0] : null
  aks_team_1_kube_config = length(module.aks_team_1) > 0 ? values(module.aks_team_1)[0].aks_cluster_kube_config[0] : null
  aks_team_2_kube_config = length(module.aks_team_2) > 0 ? values(module.aks_team_2)[0].aks_cluster_kube_config[0] : null
  aks_team_3_kube_config = length(module.aks_team_3) > 0 ? values(module.aks_team_3)[0].aks_cluster_kube_config[0] : null
  aks_team_4_kube_config = length(module.aks_team_4) > 0 ? values(module.aks_team_4)[0].aks_cluster_kube_config[0] : null
}

provider "kubernetes" {
  alias = "aks_deployment_team_0"

  host                   = local.aks_team_0_kube_config != null ? local.aks_team_0_kube_config.host : null
  client_certificate     = local.aks_team_0_kube_config != null ? base64decode(local.aks_team_0_kube_config.client_certificate) : null
  client_key             = local.aks_team_0_kube_config != null ? base64decode(local.aks_team_0_kube_config.client_key) : null
  cluster_ca_certificate = local.aks_team_0_kube_config != null ? base64decode(local.aks_team_0_kube_config.cluster_ca_certificate) : null
}

provider "kubernetes" {
  alias = "aks_deployment_team_1"

  host                   = local.aks_team_1_kube_config != null ? local.aks_team_1_kube_config.host : null
  client_certificate     = local.aks_team_1_kube_config != null ? base64decode(local.aks_team_1_kube_config.client_certificate) : null
  client_key             = local.aks_team_1_kube_config != null ? base64decode(local.aks_team_1_kube_config.client_key) : null
  cluster_ca_certificate = local.aks_team_1_kube_config != null ? base64decode(local.aks_team_1_kube_config.cluster_ca_certificate) : null
}

provider "kubernetes" {
  alias = "aks_deployment_team_2"

  host                   = local.aks_team_2_kube_config != null ? local.aks_team_2_kube_config.host : null
  client_certificate     = local.aks_team_2_kube_config != null ? base64decode(local.aks_team_2_kube_config.client_certificate) : null
  client_key             = local.aks_team_2_kube_config != null ? base64decode(local.aks_team_2_kube_config.client_key) : null
  cluster_ca_certificate = local.aks_team_2_kube_config != null ? base64decode(local.aks_team_2_kube_config.cluster_ca_certificate) : null
}

provider "kubernetes" {
  alias = "aks_deployment_team_3"

  host                   = local.aks_team_3_kube_config != null ? local.aks_team_3_kube_config.host : null
  client_certificate     = local.aks_team_3_kube_config != null ? base64decode(local.aks_team_3_kube_config.client_certificate) : null
  client_key             = local.aks_team_3_kube_config != null ? base64decode(local.aks_team_3_kube_config.client_key) : null
  cluster_ca_certificate = local.aks_team_3_kube_config != null ? base64decode(local.aks_team_3_kube_config.cluster_ca_certificate) : null
}

provider "kubernetes" {
  alias = "aks_deployment_team_4"

  host                   = local.aks_team_4_kube_config != null ? local.aks_team_4_kube_config.host : null
  client_certificate     = local.aks_team_4_kube_config != null ? base64decode(local.aks_team_4_kube_config.client_certificate) : null
  client_key             = local.aks_team_4_kube_config != null ? base64decode(local.aks_team_4_kube_config.client_key) : null
  cluster_ca_certificate = local.aks_team_4_kube_config != null ? base64decode(local.aks_team_4_kube_config.cluster_ca_certificate) : null
}

provider "helm" {
  alias = "aks_deployment_team_0"

  kubernetes {
    host                   = local.aks_team_0_kube_config != null ? local.aks_team_0_kube_config.host : null
    client_certificate     = local.aks_team_0_kube_config != null ? base64decode(local.aks_team_0_kube_config.client_certificate) : null
    client_key             = local.aks_team_0_kube_config != null ? base64decode(local.aks_team_0_kube_config.client_key) : null
    cluster_ca_certificate = local.aks_team_0_kube_config != null ? base64decode(local.aks_team_0_kube_config.cluster_ca_certificate) : null
  }
}

provider "helm" {
  alias = "aks_deployment_team_1"

  kubernetes {
    host                   = local.aks_team_1_kube_config != null ? local.aks_team_1_kube_config.host : null
    client_certificate     = local.aks_team_1_kube_config != null ? base64decode(local.aks_team_1_kube_config.client_certificate) : null
    client_key             = local.aks_team_1_kube_config != null ? base64decode(local.aks_team_1_kube_config.client_key) : null
    cluster_ca_certificate = local.aks_team_1_kube_config != null ? base64decode(local.aks_team_1_kube_config.cluster_ca_certificate) : null
  }
}

provider "helm" {
  alias = "aks_deployment_team_2"

  kubernetes {
    host                   = local.aks_team_2_kube_config != null ? local.aks_team_2_kube_config.host : null
    client_certificate     = local.aks_team_2_kube_config != null ? base64decode(local.aks_team_2_kube_config.client_certificate) : null
    client_key             = local.aks_team_2_kube_config != null ? base64decode(local.aks_team_2_kube_config.client_key) : null
    cluster_ca_certificate = local.aks_team_2_kube_config != null ? base64decode(local.aks_team_2_kube_config.cluster_ca_certificate) : null
  }
}

provider "helm" {
  alias = "aks_deployment_team_3"

  kubernetes {
    host                   = local.aks_team_3_kube_config != null ? local.aks_team_3_kube_config.host : null
    client_certificate     = local.aks_team_3_kube_config != null ? base64decode(local.aks_team_3_kube_config.client_certificate) : null
    client_key             = local.aks_team_3_kube_config != null ? base64decode(local.aks_team_3_kube_config.client_key) : null
    cluster_ca_certificate = local.aks_team_3_kube_config != null ? base64decode(local.aks_team_3_kube_config.cluster_ca_certificate) : null
  }
}

provider "helm" {
  alias = "aks_deployment_team_4"

  kubernetes {
    host                   = local.aks_team_4_kube_config != null ? local.aks_team_4_kube_config.host : null
    client_certificate     = local.aks_team_4_kube_config != null ? base64decode(local.aks_team_4_kube_config.client_certificate) : null
    client_key             = local.aks_team_4_kube_config != null ? base64decode(local.aks_team_4_kube_config.client_key) : null
    cluster_ca_certificate = local.aks_team_4_kube_config != null ? base64decode(local.aks_team_4_kube_config.cluster_ca_certificate) : null
  }
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Get current subscription information
data "azurerm_subscription" "current" {}