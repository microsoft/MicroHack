# ===============================================================================
# Terraform Configuration for Oracle on Azure Infrastructure
# ===============================================================================
# This configuration provisions multiple isolated AKS environments across up to
# five subscriptions together with the shared Oracle Database@Azure networking.
# Kubernetes users, credentials, and role assignments are created per workspace
# while networking is shared via a single delegated subnet.
# ===============================================================================

# ===============================================================================
# Local Values
# ===============================================================================

locals {
  default_location          = var.location
  default_prefix            = "user"
  default_aks_vm_size       = var.aks_vm_size
  default_aks_os_disk_type  = var.aks_os_disk_type
  default_fqdn_odaa_fra     = var.fqdn_odaa_fra
  default_fqdn_odaa_app_fra = var.fqdn_odaa_app_fra
  default_fqdn_odaa_par     = var.fqdn_odaa_par
  default_fqdn_odaa_app_par = var.fqdn_odaa_app_par

  default_aks_cidr_base  = var.aks_cidr_base
  default_service_cidr   = var.aks_service_cidr
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
      index             = idx                                                                               # originates from the user count.
      provider_index    = idx % local.subscription_target_count                                             # round robin assignment to subscription slots
      subscription_id   = local.subscription_targets[idx % local.subscription_target_count].subscription_id # round robin assignment to subscription id
      tenant_id         = local.subscription_targets[idx % local.subscription_target_count].tenant_id       # round robin assignment to corresponding tenant id
      postfix           = format("%02d", idx)
      prefix            = local.default_prefix
      location          = local.default_location
      aks_cidr          = "10.0.0.0"                                       # Same CIDR for all users (isolated by VNet, no cross-user peering)
      aks_service_cidr  = "172.${16 + floor(idx / 256)}.${idx % 256}.0/24" # Unique service CIDR in 172.16.0.0/12 to avoid 10.0.0.0/8 and 192.168.0.0/16 overlaps
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
# Identity and Credential Exports
# ===============================================================================

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

# ===============================================================================
# Oracle Cloud Enterprise App Access
# ===============================================================================

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

# Commented out - App role assignment already exists in Azure AD (created manually)
# resource "azuread_app_role_assignment" "oracle_cloud_group" {
#   count = local.oracle_cloud_app_role_id == null ? 0 : 1

#   resource_object_id  = local.oracle_cloud_service_principal.object_id
#   principal_object_id = module.entra_id_users.group_object_id
#   app_role_id         = local.oracle_cloud_app_role_id

#   lifecycle {
#     precondition {
#       condition     = local.oracle_cloud_app_role_id != null
#       error_message = "Unable to determine an app role ID for the Oracle Cloud service principal. Ensure it exposes an enabled app role (for example 'User') or set 'oracle_cloud_service_principal_app_role_value' accordingly."
#     }
#   }
# }

resource "local_file" "user_credentials" {
  filename = local.user_credentials_output_path
  content  = <<-JSON
  {
    "generated_at": ${jsonencode(local.user_credentials_export.generated_at)},
    "deployments": {
%{for deployment_name in local.deployment_names~}
%{if length(local.user_credentials_export.deployments[deployment_name]) == 0}
      ${jsonencode(deployment_name)}: []%{if index(local.deployment_names, deployment_name) < length(local.deployment_names) - 1},%{endif}
%{else}
      ${jsonencode(deployment_name)}: [
%{for credential_index, credential in local.user_credentials_export.deployments[deployment_name]~}
        {
          "user_principal_name": ${jsonencode(credential.user_principal_name)},
          "display_name": ${jsonencode(credential.display_name)},
          "initial_password": ${jsonencode(credential.initial_password)}
        }%{if credential_index < length(local.user_credentials_export.deployments[deployment_name]) - 1},%{endif}
%{endfor~}
      ]%{if index(local.deployment_names, deployment_name) < length(local.deployment_names) - 1},%{endif}
%{endif}
%{endfor~}
    }
  }
  JSON

  lifecycle {
    precondition {
      condition     = trimspace(local.user_credentials_output_path) != ""
      error_message = "The user_credentials_output_path must not resolve to an empty string."
    }
  }
}

# ===============================================================================
# Role Assignments for Shared ODAA Resources
# ===============================================================================

resource "azurerm_role_assignment" "odaa_autonomous_database_admin_per_user" {
  for_each = local.deployments

  provider             = azurerm.odaa
  scope                = local.odaa_modules[each.key].resource_group_id
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = local.deployment_user_object_ids[each.key]
  description          = "Grants ${each.value.name} exclusive admin permissions for their Oracle Autonomous Database resources in resource group ${local.odaa_modules[each.key].resource_group_name}."
}

resource "azurerm_role_definition" "private_dns_zone_reader" {
  name        = "custom-private-dns-zone-reader"
  scope       = data.azurerm_subscription.odaa.id
  description = "Allows read-only access to Private DNS Zones."

  permissions {
    actions = [
      "Microsoft.Network/privateDnsZones/read",
      "Microsoft.Network/privateDnsZones/*/read"
    ]
  }

  assignable_scopes = [
    data.azurerm_subscription.odaa.id
  ]
}

resource "azurerm_role_assignment" "odaa_private_dns_zone_reader_group" {
  provider           = azurerm.odaa
  scope              = data.azurerm_subscription.odaa.id
  role_definition_id = azurerm_role_definition.private_dns_zone_reader.role_definition_resource_id
  principal_id       = module.entra_id_users.group_object_id
  description        = "Grants ${module.entra_id_users.group_display_name} read access to Private DNS Zones across subscription ${data.azurerm_subscription.odaa.display_name}."
}



resource "azurerm_role_assignment" "odaa_subscription_manager_reader_group" {
  provider           = azurerm.odaa
  scope              = data.azurerm_subscription.odaa.id
  role_definition_id = azurerm_role_definition.oracle_subscriptions_manager_reader.role_definition_resource_id
  principal_id       = module.entra_id_users.group_object_id
  description        = "Grants ${module.entra_id_users.group_display_name} read access to Oracle Subscription resources across subscription ${data.azurerm_subscription.odaa.display_name}."
}

# ===============================================================================
# AKS Deployments per Subscription Slot
# ===============================================================================

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
  service_cidr              = each.value.aks_service_cidr
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
  service_cidr              = each.value.aks_service_cidr
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
  service_cidr              = each.value.aks_service_cidr
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
  service_cidr              = each.value.aks_service_cidr
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
  service_cidr              = each.value.aks_service_cidr
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

# ===============================================================================
# Ingress Controller Deployment
# ===============================================================================
# Ingress controllers are now deployed via the deploy-ingress-controllers.ps1 
# script after terraform apply completes. This approach removes the helm provider
# constraint and allows scaling to unlimited users.
#
# To deploy ingress controllers:
#   .\scripts\deploy-ingress-controllers.ps1
#
# To uninstall ingress controllers:
#   .\scripts\deploy-ingress-controllers.ps1 -Uninstall
# ===============================================================================

# ===============================================================================
# Per-User Oracle Database@Azure Networks (Isolated)
# ===============================================================================
# Each user gets their own ODAA VNet (192.168.0.0/16) - isolated by VNet boundaries
# No peering between ODAA VNets = complete user isolation

module "odaa_slot_0" {
  source = "./modules/odaa"

  for_each = local.aks_deployments_by_slot["0"]

  providers = {
    azurerm = azurerm.odaa
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr
  password                   = null
  create_autonomous_database = false

  tags = merge(local.common_tags, {
    ODAAFor   = each.value.name
    UserIndex = each.value.index
  })
}

module "odaa_slot_1" {
  source = "./modules/odaa"

  for_each = local.aks_deployments_by_slot["1"]

  providers = {
    azurerm = azurerm.odaa
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr
  password                   = null
  create_autonomous_database = false

  tags = merge(local.common_tags, {
    ODAAFor   = each.value.name
    UserIndex = each.value.index
  })
}

module "odaa_slot_2" {
  source = "./modules/odaa"

  for_each = local.aks_deployments_by_slot["2"]

  providers = {
    azurerm = azurerm.odaa
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr
  password                   = null
  create_autonomous_database = false

  tags = merge(local.common_tags, {
    ODAAFor   = each.value.name
    UserIndex = each.value.index
  })
}

module "odaa_slot_3" {
  source = "./modules/odaa"

  for_each = local.aks_deployments_by_slot["3"]

  providers = {
    azurerm = azurerm.odaa
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr
  password                   = null
  create_autonomous_database = false

  tags = merge(local.common_tags, {
    ODAAFor   = each.value.name
    UserIndex = each.value.index
  })
}

module "odaa_slot_4" {
  source = "./modules/odaa"

  for_each = local.aks_deployments_by_slot["4"]

  providers = {
    azurerm = azurerm.odaa
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr
  password                   = null
  create_autonomous_database = false

  tags = merge(local.common_tags, {
    ODAAFor   = each.value.name
    UserIndex = each.value.index
  })
}

# ===============================================================================
# ODAA Module Outputs Map
# ===============================================================================
# Maps each deployment key to its corresponding ODAA module output

locals {
  odaa_modules = merge(
    module.odaa_slot_0,
    module.odaa_slot_1,
    module.odaa_slot_2,
    module.odaa_slot_3,
    module.odaa_slot_4
  )
}

# ===============================================================================
# Deterministic Suffix for ADB Names
# ===============================================================================
# Creates a human-readable suffix using airport code + creation date (e.g., par251102)
# This ensures uniqueness while providing context about location and deployment time

# Capture creation timestamp once (stable across future applies)
resource "null_resource" "adb_creation_time" {
  triggers = {
    timestamp = timestamp()
  }

  lifecycle {
    ignore_changes = [triggers]
  }
}

locals {
  # Sanitize event name for OCI (alphanumeric only, max 8 chars)
  sanitized_event_name = lower(replace(replace(replace(
    substr(var.microhack_event_name, 0, 8),
  "-", ""), "_", ""), ".", ""))

  # Map Azure regions to IATA airport codes
  location_to_airport_code = {
    "francecentral"      = "par" # Paris
    "germanywestcentral" = "fra" # Frankfurt
  }

  # Get airport code for current location (fallback to first 3 chars if not found)
  airport_code = lookup(
    local.location_to_airport_code,
    lower(var.location),
    substr(replace(var.location, "/[^a-z]/", ""), 0, 3)
  )

  # Create deterministic suffix: airport code + YYMMDD (e.g., par251102)
  adb_descriptive_suffix = {
    for key, deployment in local.deployments : key => lower(format("%s%s",
      local.airport_code,
      formatdate("YYMMDD", null_resource.adb_creation_time.triggers.timestamp)
    ))
  }
}

# ===============================================================================
# Oracle Autonomous Databases
# ===============================================================================
# Creates ADB instances for each deployment. All ADBs are created in parallel.

resource "azurerm_oracle_autonomous_database" "user" {
  for_each = var.create_oracle_database ? local.deployments : {}

  name = lower(format("%s%s%s%s",
    local.sanitized_event_name,
    each.value.prefix,
    each.value.postfix,
    local.adb_descriptive_suffix[each.key]
  ))

  display_name = lower(format("%s%s%s%s",
    var.microhack_event_name,
    each.value.prefix,
    each.value.postfix,
    local.adb_descriptive_suffix[each.key]
  ))

  resource_group_name = local.odaa_modules[each.key].resource_group_name
  location            = var.location

  admin_password                   = var.adb_admin_password
  allowed_ips                      = []
  auto_scaling_enabled             = false
  auto_scaling_for_storage_enabled = false
  backup_retention_period_in_days  = 1
  character_set                    = "AL32UTF8"
  compute_count                    = 2
  compute_model                    = "ECPU"
  customer_contacts                = ["maik.sandmann@gmx.net"]
  data_storage_size_in_tbs         = 1
  db_version                       = "23ai"
  db_workload                      = "OLTP"
  license_model                    = "BringYourOwnLicense"
  mtls_connection_required         = false
  national_character_set           = "AL16UTF16"
  subnet_id                        = local.odaa_modules[each.key].subnet_id
  virtual_network_id               = local.odaa_modules[each.key].vnet_id

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
    ODAAFor       = each.value.name
  })

  depends_on = [
    module.odaa_slot_0,
    module.odaa_slot_1,
    module.odaa_slot_2,
    module.odaa_slot_3,
    module.odaa_slot_4
  ]
}

# ===============================================================================
# VNet Peering Between AKS and Shared ODAA Network
# ===============================================================================

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
  odaa_vnet_id         = module.odaa_slot_0[each.key].vnet_id
  odaa_vnet_name       = module.odaa_slot_0[each.key].vnet_name
  odaa_resource_group  = module.odaa_slot_0[each.key].resource_group_name
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
  odaa_vnet_id         = module.odaa_slot_1[each.key].vnet_id
  odaa_vnet_name       = module.odaa_slot_1[each.key].vnet_name
  odaa_resource_group  = module.odaa_slot_1[each.key].resource_group_name
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
  odaa_vnet_id         = module.odaa_slot_2[each.key].vnet_id
  odaa_vnet_name       = module.odaa_slot_2[each.key].vnet_name
  odaa_resource_group  = module.odaa_slot_2[each.key].resource_group_name
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
  odaa_vnet_id         = module.odaa_slot_3[each.key].vnet_id
  odaa_vnet_name       = module.odaa_slot_3[each.key].vnet_name
  odaa_resource_group  = module.odaa_slot_3[each.key].resource_group_name
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
  odaa_vnet_id         = module.odaa_slot_4[each.key].vnet_id
  odaa_vnet_name       = module.odaa_slot_4[each.key].vnet_name
  odaa_resource_group  = module.odaa_slot_4[each.key].resource_group_name
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

output "odaa_networks" {
  description = "Information about the per-user ODAA networks"
  value = {
    for key, deployment in local.deployments : deployment.name => {
      resource_group_name = local.odaa_modules[key].resource_group_name
      resource_group_id   = local.odaa_modules[key].resource_group_id
      vnet_id             = local.odaa_modules[key].vnet_id
      vnet_name           = local.odaa_modules[key].vnet_name
      subnet_id           = local.odaa_modules[key].subnet_id
    }
  }
}

output "odaa_autonomous_databases" {
  description = "Oracle Autonomous Databases provisioned for each deployment"
  value = {
    for key, deployment in local.deployments : deployment.name => (
      var.create_oracle_database && contains(keys(azurerm_oracle_autonomous_database.user), key) ?
      {
        id                  = azurerm_oracle_autonomous_database.user[key].id
        name                = azurerm_oracle_autonomous_database.user[key].name
        display_name        = azurerm_oracle_autonomous_database.user[key].display_name
        resource_group_name = local.odaa_modules[key].resource_group_name
        descriptive_suffix  = local.adb_descriptive_suffix[key]
      } : null
    )
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

output "aks_kubeconfigs" {
  description = "Kubeconfig files for all AKS clusters (for deployment automation only)"
  value = {
    for key, deployment in local.deployments : deployment.name => {
      kubeconfig_raw      = local.aks_modules[key].aks_cluster_kube_config_raw
      cluster_name        = local.aks_modules[key].aks_cluster_name
      resource_group_name = local.aks_modules[key].resource_group_name
      subscription_id     = deployment.subscription_id
    }
  }
  sensitive = true
}

