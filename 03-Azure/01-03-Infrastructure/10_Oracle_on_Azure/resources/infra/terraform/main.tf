# ===============================================================================
# Terraform Configuration for Oracle on Azure Infrastructure
# ===============================================================================
# This configuration provisions up to five AKS deployments, each in its own
# subscription, along with the corresponding Oracle Database on Azure (ODAA)
# networking components. DNS is integrated into the AKS module for better
# encapsulation.
# ===============================================================================

# ===============================================================================
# Local Values
# ===============================================================================


# ===============================================================================
# Entra ID Variables
# ===============================================================================

locals {
  default_location          = var.location
  default_prefix            = var.prefix
  default_aks_vm_size       = var.aks_vm_size
  default_aks_os_disk_type  = var.aks_os_disk_type
  default_fqdn_odaa_fra     = var.fqdn_odaa_fra
  default_fqdn_odaa_app_fra = var.fqdn_odaa_app_fra
  default_fqdn_odaa_par     = var.fqdn_odaa_par
  default_fqdn_odaa_app_par = var.fqdn_odaa_app_par

  # Modules expect the base network value without the CIDR suffix.
  default_aks_cidr_base  = var.aks_cidr_base
  default_odaa_cidr_base = var.odaa_cidr_base

  common_tags = {
    Project   = var.microhack_event_name
    ManagedBy = "Terraform"
  }

  subscription_targets      = var.subscription_targets
  subscription_target_count = length(local.subscription_targets)
  user_indices              = range(var.user_count)

  deployments = {
    for idx in local.user_indices :
    tostring(idx) => {
      index             = idx
      provider_index    = idx % local.subscription_target_count
      subscription_id   = local.subscription_targets[idx % local.subscription_target_count].subscription_id
      tenant_id         = local.subscription_targets[idx % local.subscription_target_count].tenant_id
      postfix           = format("%02d", idx)
      prefix            = local.default_prefix
      location          = local.default_location
      aks_cidr          = local.default_aks_cidr_base
      aks_vm_size       = local.default_aks_vm_size
      aks_os_disk_type  = local.default_aks_os_disk_type
      odaa_cidr         = local.default_odaa_cidr_base
      fqdn_odaa_fra     = local.default_fqdn_odaa_fra
      fqdn_odaa_app_fra = local.default_fqdn_odaa_app_fra
      fqdn_odaa_par     = local.default_fqdn_odaa_par
      fqdn_odaa_app_par = local.default_fqdn_odaa_app_par
      name              = format("%s%02d", local.default_prefix, idx)
      user_identifier   = lower(format("%s%02d", local.default_prefix, idx))
    }
  }

  aks_deployments_by_slot = {
    for idx in range(5) :
    tostring(idx) => {
      for key, deployment in local.deployments :
      key => deployment if deployment.provider_index == idx
    }
  }

  deployment_names = [for deployment in values(local.deployments) : deployment.name]

  tenant_ids = distinct([for deployment in values(local.deployments) : deployment.tenant_id])

  shared_deployment_group = {
    name        = "mh-odaa-user-grp"
    description = "Security group with rights to deploy applications to the Oracle AKS cluster"
  }

  shared_deployment_group_tenant_id = try(local.tenant_ids[0], var.odaa_tenant_id)

  deployment_users = {
    for key, deployment in local.deployments :
    key => {
      identifier = deployment.user_identifier
    }
  }
}

# ===============================================================================
# Modules
# ===============================================================================

# Provider registrations for the ODAA subscription should be handled manually.
# Removing these resources avoids import requirements when providers are already registered
# or automatically managed by the AzureRM provider.

# Entra ID identities (single shared group, per-user accounts)
module "entra_id_users" {
  source = "./modules/entra-id"

  providers = {
    azuread = azuread.aks_deployment_slot_0
  }

  aks_deployment_group_name        = local.shared_deployment_group.name
  aks_deployment_group_description = local.shared_deployment_group.description
  tenant_id                        = local.shared_deployment_group_tenant_id
  user_principal_domain            = var.entra_user_principal_domain
  users                            = local.deployment_users
  tags = merge(local.common_tags, {
    AKSDeploymentGroup = local.shared_deployment_group.name
  })
}

locals {
  deployment_user_credentials = {
    for key, deployment in local.deployments :
    key => lookup(module.entra_id_users.user_credentials, key, null)
  }

  user_credentials_export = {
    generated_at = timestamp()
    deployments = {
      for key, deployment in local.deployments :
      deployment.name => (
        local.deployment_user_credentials[key] == null ?
        [] :
        [
          {
            user_principal_name = local.deployment_user_credentials[key].user_principal_name
            display_name        = local.deployment_user_credentials[key].display_name
            initial_password    = local.deployment_user_credentials[key].initial_password
          }
        ]
      )
    }
  }
  user_credentials_output_path = (
    var.user_credentials_output_path != null ?
    var.user_credentials_output_path :
    abspath("${path.root}/user_credentials.json")
  )

  deployment_user_object_ids      = module.entra_id_users.user_object_ids
  deployment_user_principal_names = module.entra_id_users.user_principal_names
}

data "azuread_service_principal" "oracle_cloud" {
  count     = var.oracle_cloud_service_principal_object_id == null ? 0 : 1
  object_id = var.oracle_cloud_service_principal_object_id
}

data "azurerm_subscription" "odaa" {
  subscription_id = var.odaa_subscription_id
}

locals {
  oracle_cloud_service_principal = var.oracle_cloud_service_principal_object_id == null ? null : try(data.azuread_service_principal.oracle_cloud[0], null)

  oracle_cloud_app_roles = local.oracle_cloud_service_principal == null ? [] : [
    for role in local.oracle_cloud_service_principal.app_roles : role
    if role.enabled
  ]

  oracle_cloud_app_role_id_from_value = (
    local.oracle_cloud_service_principal == null ? null : (
      var.oracle_cloud_service_principal_app_role_value == null ? null : (
        contains(keys(local.oracle_cloud_service_principal.app_role_ids), var.oracle_cloud_service_principal_app_role_value) ?
        local.oracle_cloud_service_principal.app_role_ids[var.oracle_cloud_service_principal_app_role_value] :
        try(([
          for role in local.oracle_cloud_app_roles : role.id
          if role.value == var.oracle_cloud_service_principal_app_role_value
        ])[0], null)
      )
    )
  )

  oracle_cloud_app_role_id_by_display_name = local.oracle_cloud_service_principal == null ? null : try(([
    for role in local.oracle_cloud_app_roles : role.id
    if lower(role.display_name) == "user"
  ])[0], null)

  oracle_cloud_app_role_default_id = local.oracle_cloud_service_principal == null ? null : try(local.oracle_cloud_app_roles[0].id, null)

  oracle_cloud_app_role_id = local.oracle_cloud_service_principal == null ? null : (
    local.oracle_cloud_app_role_id_from_value != null ?
    local.oracle_cloud_app_role_id_from_value : (
      local.oracle_cloud_app_role_id_by_display_name != null ?
      local.oracle_cloud_app_role_id_by_display_name :
      local.oracle_cloud_app_role_default_id
    )
  )
}

resource "azuread_app_role_assignment" "oracle_cloud_group" {
  count = local.oracle_cloud_app_role_id == null ? 0 : 1

  resource_object_id  = local.oracle_cloud_service_principal.object_id
  principal_object_id = module.entra_id_users.group_object_id
  app_role_id         = local.oracle_cloud_app_role_id

  lifecycle {
    precondition {
      condition     = local.oracle_cloud_app_role_id != null
      error_message = "Unable to determine an app role ID for the Oracle Cloud service principal. Ensure it exposes an enabled app role (for example 'User') or set 'oracle_cloud_service_principal_app_role_value' accordingly."
    }
  }
}

resource "local_file" "user_credentials" {
  count    = var.disable_user_credentials_export ? 0 : 1
  filename = local.user_credentials_output_path
  content  = jsonencode(local.user_credentials_export)

  lifecycle {
    precondition {
      condition     = trimspace(local.user_credentials_output_path) != ""
      error_message = "The user_credentials_output_path must not resolve to an empty string."
    }
  }
}

resource "azurerm_role_assignment" "odaa_autonomous_database_admin" {
  provider             = azurerm.odaa
  for_each             = local.deployment_user_object_ids
  scope                = module.odaa[each.key].resource_group_id
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = each.value
  description          = "Grants ${lookup(local.deployment_user_principal_names, each.key, each.key)} permissions to manage Oracle Autonomous Database resources in resource group ${module.odaa[each.key].resource_group_name}."
}

resource "azurerm_role_assignment" "odaa_subscription_manager_reader" {
  provider           = azurerm.odaa
  for_each           = local.deployment_user_object_ids
  scope              = module.odaa[each.key].resource_group_id
  role_definition_id = azurerm_role_definition.oracle_subscriptions_manager_reader.role_definition_resource_id
  principal_id       = each.value
  description        = "Grants ${lookup(local.deployment_user_principal_names, each.key, each.key)} read access to Oracle Subscription resources in resource group ${module.odaa[each.key].resource_group_name}."
}

resource "azurerm_role_assignment" "odaa_subscription_manager_reader_group" {
  provider           = azurerm.odaa
  scope              = data.azurerm_subscription.odaa.id
  role_definition_id = azurerm_role_definition.oracle_subscriptions_manager_reader.role_definition_resource_id
  principal_id       = module.entra_id_users.group_object_id
  description        = "Grants ${module.entra_id_users.group_display_name} read access to Oracle Subscription resources across subscription ${data.azurerm_subscription.odaa.display_name}."
}

# AKS Deployments per subscription
module "aks_slot_0" {
  for_each = local.aks_deployments_by_slot["0"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_slot_0
  }

  prefix                    = each.value.prefix
  postfix                   = each.value.postfix
  location                  = each.value.location
  cidr                      = each.value.aks_cidr
  aks_vm_size               = each.value.aks_vm_size
  os_disk_type              = each.value.aks_os_disk_type
  deployment_user_object_id = local.deployment_user_object_ids[each.key]
  subscription_id           = each.value.subscription_id
  fqdn_odaa_fra             = each.value.fqdn_odaa_fra
  fqdn_odaa_app_fra         = each.value.fqdn_odaa_app_fra
  fqdn_odaa_par             = each.value.fqdn_odaa_par
  fqdn_odaa_app_par         = each.value.fqdn_odaa_app_par

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "aks_slot_1" {
  for_each = local.aks_deployments_by_slot["1"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_slot_1
  }

  prefix                    = each.value.prefix
  postfix                   = each.value.postfix
  location                  = each.value.location
  cidr                      = each.value.aks_cidr
  aks_vm_size               = each.value.aks_vm_size
  os_disk_type              = each.value.aks_os_disk_type
  deployment_user_object_id = local.deployment_user_object_ids[each.key]
  subscription_id           = each.value.subscription_id
  fqdn_odaa_fra             = each.value.fqdn_odaa_fra
  fqdn_odaa_app_fra         = each.value.fqdn_odaa_app_fra
  fqdn_odaa_par             = each.value.fqdn_odaa_par
  fqdn_odaa_app_par         = each.value.fqdn_odaa_app_par

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "aks_slot_2" {
  for_each = local.aks_deployments_by_slot["2"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_slot_2
  }

  prefix                    = each.value.prefix
  postfix                   = each.value.postfix
  location                  = each.value.location
  cidr                      = each.value.aks_cidr
  aks_vm_size               = each.value.aks_vm_size
  os_disk_type              = each.value.aks_os_disk_type
  deployment_user_object_id = local.deployment_user_object_ids[each.key]
  subscription_id           = each.value.subscription_id
  fqdn_odaa_fra             = each.value.fqdn_odaa_fra
  fqdn_odaa_app_fra         = each.value.fqdn_odaa_app_fra
  fqdn_odaa_par             = each.value.fqdn_odaa_par
  fqdn_odaa_app_par         = each.value.fqdn_odaa_app_par

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "aks_slot_3" {
  for_each = local.aks_deployments_by_slot["3"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_slot_3
  }

  prefix                    = each.value.prefix
  postfix                   = each.value.postfix
  location                  = each.value.location
  cidr                      = each.value.aks_cidr
  aks_vm_size               = each.value.aks_vm_size
  os_disk_type              = each.value.aks_os_disk_type
  deployment_user_object_id = local.deployment_user_object_ids[each.key]
  subscription_id           = each.value.subscription_id
  fqdn_odaa_fra             = each.value.fqdn_odaa_fra
  fqdn_odaa_app_fra         = each.value.fqdn_odaa_app_fra
  fqdn_odaa_par             = each.value.fqdn_odaa_par
  fqdn_odaa_app_par         = each.value.fqdn_odaa_app_par
  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "aks_slot_4" {
  for_each = local.aks_deployments_by_slot["4"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_slot_4
  }

  prefix                    = each.value.prefix
  postfix                   = each.value.postfix
  location                  = each.value.location
  cidr                      = each.value.aks_cidr
  aks_vm_size               = each.value.aks_vm_size
  os_disk_type              = each.value.aks_os_disk_type
  deployment_user_object_id = local.deployment_user_object_ids[each.key]
  subscription_id           = each.value.subscription_id
  fqdn_odaa_fra             = each.value.fqdn_odaa_fra
  fqdn_odaa_app_fra         = each.value.fqdn_odaa_app_fra
  fqdn_odaa_par             = each.value.fqdn_odaa_par
  fqdn_odaa_app_par         = each.value.fqdn_odaa_app_par

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

locals {
  aks_modules = merge(
    module.aks_slot_0,
    module.aks_slot_1,
    module.aks_slot_2,
    module.aks_slot_3,
    module.aks_slot_4,
  )
}

module "ingress_nginx_slot_0" {
  for_each = local.aks_deployments_by_slot["0"]
  source   = "./modules/ingress-nginx"

  providers = {
    helm = helm.aks_deployment_slot_0
  }
}

module "ingress_nginx_slot_1" {
  for_each = local.aks_deployments_by_slot["1"]
  source   = "./modules/ingress-nginx"

  providers = {
    helm = helm.aks_deployment_slot_1
  }
}

module "ingress_nginx_slot_2" {
  for_each = local.aks_deployments_by_slot["2"]
  source   = "./modules/ingress-nginx"

  providers = {
    helm = helm.aks_deployment_slot_2
  }
}

module "ingress_nginx_slot_3" {
  for_each = local.aks_deployments_by_slot["3"]
  source   = "./modules/ingress-nginx"

  providers = {
    helm = helm.aks_deployment_slot_3
  }
}

module "ingress_nginx_slot_4" {
  for_each = local.aks_deployments_by_slot["4"]
  source   = "./modules/ingress-nginx"

  providers = {
    helm = helm.aks_deployment_slot_4
  }
}

# ODAA Deployments (shared subscription)
module "odaa" {
  for_each = local.deployments
  source   = "./modules/odaa"

  providers = {
    azurerm = azurerm.odaa
    azapi   = azapi
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr
  password                   = var.adb_admin_password
  create_autonomous_database = var.create_oracle_database

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
    ODAAFor       = each.value.name
  })
}

# VNet Peering between AKS and ODAA VNets
module "vnet_peering_slot_0" {
  for_each = local.aks_deployments_by_slot["0"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_slot_0
    azurerm.odaa = azurerm.odaa
  }

  aks_vnet_id          = local.aks_modules[each.key].vnet_id
  aks_vnet_name        = local.aks_modules[each.key].vnet_name
  aks_resource_group   = local.aks_modules[each.key].resource_group_name
  odaa_vnet_id         = module.odaa[each.key].vnet_id
  odaa_vnet_name       = module.odaa[each.key].vnet_name
  odaa_resource_group  = module.odaa[each.key].resource_group_name
  odaa_subscription_id = var.odaa_subscription_id
  peering_suffix       = each.value.name

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
    PeeringFor    = each.value.name
  })
}

module "vnet_peering_slot_1" {
  for_each = local.aks_deployments_by_slot["1"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_slot_1
    azurerm.odaa = azurerm.odaa
  }

  aks_vnet_id          = local.aks_modules[each.key].vnet_id
  aks_vnet_name        = local.aks_modules[each.key].vnet_name
  aks_resource_group   = local.aks_modules[each.key].resource_group_name
  odaa_vnet_id         = module.odaa[each.key].vnet_id
  odaa_vnet_name       = module.odaa[each.key].vnet_name
  odaa_resource_group  = module.odaa[each.key].resource_group_name
  odaa_subscription_id = var.odaa_subscription_id
  peering_suffix       = each.value.name

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
    PeeringFor    = each.value.name
  })
}

module "vnet_peering_slot_2" {
  for_each = local.aks_deployments_by_slot["2"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_slot_2
    azurerm.odaa = azurerm.odaa
  }

  aks_vnet_id          = local.aks_modules[each.key].vnet_id
  aks_vnet_name        = local.aks_modules[each.key].vnet_name
  aks_resource_group   = local.aks_modules[each.key].resource_group_name
  odaa_vnet_id         = module.odaa[each.key].vnet_id
  odaa_vnet_name       = module.odaa[each.key].vnet_name
  odaa_resource_group  = module.odaa[each.key].resource_group_name
  odaa_subscription_id = var.odaa_subscription_id
  peering_suffix       = each.value.name

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
    PeeringFor    = each.value.name
  })
}

module "vnet_peering_slot_3" {
  for_each = local.aks_deployments_by_slot["3"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_slot_3
    azurerm.odaa = azurerm.odaa
  }

  aks_vnet_id          = local.aks_modules[each.key].vnet_id
  aks_vnet_name        = local.aks_modules[each.key].vnet_name
  aks_resource_group   = local.aks_modules[each.key].resource_group_name
  odaa_vnet_id         = module.odaa[each.key].vnet_id
  odaa_vnet_name       = module.odaa[each.key].vnet_name
  odaa_resource_group  = module.odaa[each.key].resource_group_name
  odaa_subscription_id = var.odaa_subscription_id
  peering_suffix       = each.value.name

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
    PeeringFor    = each.value.name
  })
}

module "vnet_peering_slot_4" {
  for_each = local.aks_deployments_by_slot["4"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_slot_4
    azurerm.odaa = azurerm.odaa
  }

  aks_vnet_id          = local.aks_modules[each.key].vnet_id
  aks_vnet_name        = local.aks_modules[each.key].vnet_name
  aks_resource_group   = local.aks_modules[each.key].resource_group_name
  odaa_vnet_id         = module.odaa[each.key].vnet_id
  odaa_vnet_name       = module.odaa[each.key].vnet_name
  odaa_resource_group  = module.odaa[each.key].resource_group_name
  odaa_subscription_id = var.odaa_subscription_id
  peering_suffix       = each.value.name

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
    PeeringFor    = each.value.name
  })
}

locals {
  vnet_peering_modules = merge(
    module.vnet_peering_slot_0,
    module.vnet_peering_slot_1,
    module.vnet_peering_slot_2,
    module.vnet_peering_slot_3,
    module.vnet_peering_slot_4,
  )
}
# ===============================================================================
# Outputs
# ===============================================================================

output "aks_clusters" {
  description = "Information about all AKS clusters deployed"
  value = {
    for key, deployment in local.deployments : deployment.name => {
      cluster_id          = local.aks_modules[key].aks_cluster_id
      cluster_name        = local.aks_modules[key].aks_cluster_name
      vnet_id             = local.aks_modules[key].vnet_id
      vnet_name           = local.aks_modules[key].vnet_name
      resource_group_name = local.aks_modules[key].resource_group_name
      dns_zones           = local.aks_modules[key].dns_zones
    }
  }
}

output "odaa_vnets" {
  description = "Information about all ODAA VNets created"
  value = {
    for key, deployment in local.deployments : deployment.name => {
      adb_id              = module.odaa[key].adb_id
      vnet_id             = module.odaa[key].vnet_id
      vnet_name           = module.odaa[key].vnet_name
      resource_group_name = module.odaa[key].resource_group_name
    }
  }
}

output "entra_id_deployment_group" {
  description = "Information about the Entra ID deployment groups"
  value = {
    for key, deployment in local.deployments : deployment.name => {
      object_id     = module.entra_id_users.group_object_id
      display_name  = module.entra_id_users.group_display_name
      mail_nickname = module.entra_id_users.group_mail_nickname
    }
  }
}

output "entra_id_deployment_users" {
  description = "Initial credentials for the users created in each Entra ID deployment group"
  value = {
    for key, deployment in local.deployments : deployment.name => (
      lookup(module.entra_id_users.user_credentials, key, null) == null ?
      {} :
      {
        key = module.entra_id_users.user_credentials[key]
      }
    )
  }
  sensitive = true
}

output "vnet_peering_connections" {
  description = "Information about all VNet peering connections"
  value = {
    for key, deployment in local.deployments : deployment.name => {
      aks_to_odaa_peering_id = local.vnet_peering_modules[key].aks_to_odaa_peering_id
      odaa_to_aks_peering_id = local.vnet_peering_modules[key].odaa_to_aks_peering_id
    }
  }
}

output "deployment_summary" {
  description = "Summary of all deployments"
  value = {
    total_aks_deployments = length(local.deployments)
    deployment_names      = local.deployment_names
    odaa_subscription_id  = var.odaa_subscription_id
    entra_group_display_names = {
      for key, deployment in local.deployments : deployment.name => module.entra_id_users.group_display_name
    }
  }
}

