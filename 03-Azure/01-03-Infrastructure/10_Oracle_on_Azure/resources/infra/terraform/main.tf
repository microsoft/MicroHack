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

locals {
  default_location      = var.location
  default_prefix        = var.prefix
  default_aks_vm_size   = var.aks_vm_size
  default_fqdn_odaa     = var.fqdn_odaa
  default_fqdn_odaa_app = var.fqdn_odaa_app

  # Modules expect the base network value without the CIDR suffix.
  default_aks_cidr_base  = var.aks_cidr_base
  default_odaa_cidr_base = var.odaa_cidr_base

  common_tags = {
    Project   = var.microhack_event_name
    ManagedBy = "Terraform"
  }
  deployments = {
    for idx in range(length(var.aks_deployments)) :
    tostring(idx) => {
      index             = idx
      subscription_id   = var.aks_deployments[idx].subscription_id
      tenant_id         = var.aks_deployments[idx].tenant_id
      postfix           = tostring(idx)
      prefix            = local.default_prefix
      location          = local.default_location
      aks_cidr          = local.default_aks_cidr_base
      aks_vm_size       = local.default_aks_vm_size
      odaa_cidr         = local.default_odaa_cidr_base
      fqdn_odaa         = local.default_fqdn_odaa
      fqdn_odaa_app     = local.default_fqdn_odaa_app
      group_name        = "${var.aks_deployment_group_name}-${tostring(idx)}"
      group_description = "${var.aks_deployment_group_description} (Deployment ${local.default_prefix}${tostring(idx)})"
      name              = "${local.default_prefix}${tostring(idx)}"
    }
  }
  aks_deployments_by_index = {
    for idx in range(5) :
    tostring(idx) => {
      for key, deployment in local.deployments :
      key => deployment if deployment.index == idx
    }
  }

  deployment_names = [for deployment in values(local.deployments) : deployment.name]
}

# ===============================================================================
# Modules
# ===============================================================================

# Provider registrations for the ODAA subscription should be handled manually.
# Removing these resources avoids import requirements when providers are already registered
# or automatically managed by the AzureRM provider.

# Entra ID Groups per AKS deployment
module "entra_id_team_0" {
  for_each = local.aks_deployments_by_index["0"]
  source   = "./modules/entra-id"

  providers = {
    azuread = azuread.aks_deployment_team_0
  }

  aks_deployment_group_name        = each.value.group_name
  aks_deployment_group_description = each.value.group_description
  tenant_id                        = each.value.tenant_id
  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "entra_id_team_1" {
  for_each = local.aks_deployments_by_index["1"]
  source   = "./modules/entra-id"

  providers = {
    azuread = azuread.aks_deployment_team_1
  }

  aks_deployment_group_name        = each.value.group_name
  aks_deployment_group_description = each.value.group_description
  tenant_id                        = each.value.tenant_id
  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "entra_id_team_2" {
  for_each = local.aks_deployments_by_index["2"]
  source   = "./modules/entra-id"

  providers = {
    azuread = azuread.aks_deployment_team_2
  }

  aks_deployment_group_name        = each.value.group_name
  aks_deployment_group_description = each.value.group_description
  tenant_id                        = each.value.tenant_id
  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "entra_id_team_3" {
  for_each = local.aks_deployments_by_index["3"]
  source   = "./modules/entra-id"

  providers = {
    azuread = azuread.aks_deployment_team_3
  }

  aks_deployment_group_name        = each.value.group_name
  aks_deployment_group_description = each.value.group_description
  tenant_id                        = each.value.tenant_id
  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "entra_id_team_4" {
  for_each = local.aks_deployments_by_index["4"]
  source   = "./modules/entra-id"

  providers = {
    azuread = azuread.aks_deployment_team_4
  }

  aks_deployment_group_name        = each.value.group_name
  aks_deployment_group_description = each.value.group_description
  tenant_id                        = each.value.tenant_id
  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

locals {
  entra_id_modules = merge(
    module.entra_id_team_0,
    module.entra_id_team_1,
    module.entra_id_team_2,
    module.entra_id_team_3,
    module.entra_id_team_4,
  )
}

# AKS Deployments per subscription
module "aks_team_0" {
  for_each = local.aks_deployments_by_index["0"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_team_0
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.aks_cidr
  aks_vm_size                = each.value.aks_vm_size
  deployment_group_object_id = local.entra_id_modules[each.key].group_object_id
  fqdn_odaa                  = each.value.fqdn_odaa
  fqdn_odaa_app              = each.value.fqdn_odaa_app

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "aks_team_1" {
  for_each = local.aks_deployments_by_index["1"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_team_1
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.aks_cidr
  aks_vm_size                = each.value.aks_vm_size
  deployment_group_object_id = local.entra_id_modules[each.key].group_object_id
  fqdn_odaa                  = each.value.fqdn_odaa
  fqdn_odaa_app              = each.value.fqdn_odaa_app

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "aks_team_2" {
  for_each = local.aks_deployments_by_index["2"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_team_2
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.aks_cidr
  aks_vm_size                = each.value.aks_vm_size
  deployment_group_object_id = local.entra_id_modules[each.key].group_object_id
  fqdn_odaa                  = each.value.fqdn_odaa
  fqdn_odaa_app              = each.value.fqdn_odaa_app

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "aks_team_3" {
  for_each = local.aks_deployments_by_index["3"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_team_3
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.aks_cidr
  aks_vm_size                = each.value.aks_vm_size
  deployment_group_object_id = local.entra_id_modules[each.key].group_object_id
  fqdn_odaa                  = each.value.fqdn_odaa
  fqdn_odaa_app              = each.value.fqdn_odaa_app

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

module "aks_team_4" {
  for_each = local.aks_deployments_by_index["4"]
  source   = "./modules/aks"

  providers = {
    azurerm = azurerm.aks_deployment_team_4
  }

  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.aks_cidr
  aks_vm_size                = each.value.aks_vm_size
  deployment_group_object_id = local.entra_id_modules[each.key].group_object_id
  fqdn_odaa                  = each.value.fqdn_odaa
  fqdn_odaa_app              = each.value.fqdn_odaa_app

  tags = merge(local.common_tags, {
    AKSDeployment = each.value.name
  })
}

locals {
  aks_modules = merge(
    module.aks_team_0,
    module.aks_team_1,
    module.aks_team_2,
    module.aks_team_3,
    module.aks_team_4,
  )
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
module "vnet_peering_team_0" {
  for_each = local.aks_deployments_by_index["0"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_team_0
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

module "vnet_peering_team_1" {
  for_each = local.aks_deployments_by_index["1"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_team_1
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

module "vnet_peering_team_2" {
  for_each = local.aks_deployments_by_index["2"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_team_2
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

module "vnet_peering_team_3" {
  for_each = local.aks_deployments_by_index["3"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_team_3
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

module "vnet_peering_team_4" {
  for_each = local.aks_deployments_by_index["4"]
  source   = "./modules/vnet-peering"

  providers = {
    azurerm.aks  = azurerm.aks_deployment_team_4
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

# Ingress NGINX deployment per AKS cluster
module "ingress_nginx_team_0" {
  for_each = module.aks_team_0
  source   = "./modules/ingress-nginx"

  providers = {
    kubernetes = kubernetes.aks_deployment_team_0
    helm       = helm.aks_deployment_team_0
  }

  release_name = "nginx-quick"
  namespace    = "ingress-nginx"

  depends_on = [
    module.aks_team_0
  ]
}

module "ingress_nginx_team_1" {
  for_each = module.aks_team_1
  source   = "./modules/ingress-nginx"

  providers = {
    kubernetes = kubernetes.aks_deployment_team_1
    helm       = helm.aks_deployment_team_1
  }

  release_name = "nginx-quick"
  namespace    = "ingress-nginx"

  depends_on = [
    module.aks_team_1
  ]
}

module "ingress_nginx_team_2" {
  for_each = module.aks_team_2
  source   = "./modules/ingress-nginx"

  providers = {
    kubernetes = kubernetes.aks_deployment_team_2
    helm       = helm.aks_deployment_team_2
  }

  release_name = "nginx-quick"
  namespace    = "ingress-nginx"

  depends_on = [
    module.aks_team_2
  ]
}

module "ingress_nginx_team_3" {
  for_each = module.aks_team_3
  source   = "./modules/ingress-nginx"

  providers = {
    kubernetes = kubernetes.aks_deployment_team_3
    helm       = helm.aks_deployment_team_3
  }

  release_name = "nginx-quick"
  namespace    = "ingress-nginx"

  depends_on = [
    module.aks_team_3
  ]
}

module "ingress_nginx_team_4" {
  for_each = module.aks_team_4
  source   = "./modules/ingress-nginx"

  providers = {
    kubernetes = kubernetes.aks_deployment_team_4
    helm       = helm.aks_deployment_team_4
  }

  release_name = "nginx-quick"
  namespace    = "ingress-nginx"

  depends_on = [
    module.aks_team_4
  ]
}

locals {
  vnet_peering_modules = merge(
    module.vnet_peering_team_0,
    module.vnet_peering_team_1,
    module.vnet_peering_team_2,
    module.vnet_peering_team_3,
    module.vnet_peering_team_4,
  )
}

locals {
  ingress_nginx_modules = merge(
    module.ingress_nginx_team_0,
    module.ingress_nginx_team_1,
    module.ingress_nginx_team_2,
    module.ingress_nginx_team_3,
    module.ingress_nginx_team_4,
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
      object_id     = local.entra_id_modules[key].group_object_id
      display_name  = local.entra_id_modules[key].group_display_name
      mail_nickname = local.entra_id_modules[key].group_mail_nickname
    }
  }
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

output "ingress_nginx_controllers" {
  description = "Information about ingress-nginx controllers per AKS deployment"
  value = {
    for key, deployment in local.deployments : deployment.name => {
      release_name = try(local.ingress_nginx_modules[key].release_name, null)
      namespace    = try(local.ingress_nginx_modules[key].namespace, null)
      service_ip   = try(local.ingress_nginx_modules[key].controller_service_ip, null)
      annotations  = try(local.ingress_nginx_modules[key].service_annotations, null)
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
      for key, deployment in local.deployments : deployment.name => local.entra_id_modules[key].group_display_name
    }
  }
}

